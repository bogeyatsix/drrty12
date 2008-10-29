# MaMaDupe Pre-release 1.1
# http://www.macupdate.com/info.php/id/29224/mamadupe
# CHANGES: No longer creates a SHA1 column cause it makes Aperture freak out.
# TO DO: Automatically mark duplicates as "rejected"

require 'osx/cocoa'
require 'digest/sha1'
require 'digest/md5'
require 'open3'
require 'pp'

include OSX

class MamaController < NSObject

  ib_outlets  :statusField, :statusLevel, :viewImage,
              :runButton, :previewButton, :forceReindexButton

  def initialize
    $controller = self
    @aperture = Aperture.new
    @reindex = false
    @stack = true
    @unstack = false
    @reject = false
    @lastState = nil
    @save_every = 100
  end

  def awakeFromNib
  	prerun()
  end

  def prerun
  	@run = false
  	@runButton.setTitle('Start')
  	@runButton.setAction(:start)
    tables_ready = @aperture.setupTables()
    unless tables_ready
       show("Something went wrong while creating the index. Unable to continue.")
     	 @runButton.setTitle('')
       @runButton.setAction(:abort)
    end
  end

  def start
    	@run = true
    	@runButton.setTitle('Stop')
    	@runButton.setAction(:stop)
    	main()
  end

  def abort
    show("Please restart the application to try again.")
  end

  def stop
    @run = false
    @runButton.setTitle('Resume')
    @runButton.setAction(:resume)
  end

  def resume  
    @run = true
    @runButton.setTitle('Stop')
    @runButton.setAction(:stop)
  end

  def main
    @generate_go = @find = false
    @clean_slate_thr = NSTimer.scheduledTimerWithTimeInterval_target_selector_userInfo_repeats(0.1, self, :clean_slate, nil, true) if @reindex
    show "Searching for unindexed images." 
    @find = true
    @get_unindexed_thr = NSTimer.scheduledTimerWithTimeInterval_target_selector_userInfo_repeats(0.1, self, :get_unindexed_pics, nil, true)
    @sha1_update_all, @count = MultilineQuery.new, 0
  	@generate_hash_thr = NSTimer.scheduledTimerWithTimeInterval_target_selector_userInfo_repeats(0.001, self, :generate_hashes, nil, true)
  end

  def chooseLibrary_deprecated
      oPanel = NSOpenPanel.openPanel
      oPanel.setAllowsMultipleSelection(false)
      oPanel.setAlphaValue(0.95)
      oPanel.setTitle("Select an Aperture library:")
  	
    	if oPanel.runModalForDirectory_file_types(nil,nil,['aplibrary']) == NSOKButton
    		fullpath = oPanel.filenames.to_a.first.to_s
    		@aperture.libpath,@aperture.dbpath = fullpath.gsub(/ /,'\ ') + "/", (fullpath + "/Aperture.aplib/Library.apdb").gsub(/ /,'\ ')
    		show "Current library @ #{@aperture.libpath.gsub(/\\/,'')}"
    	end
  end

  def printReindexStatus 
      if @forceReindexButton.state == 1
        @reindex = true
        show "All images in the library will be reindexed."
      else
        @reindex = false
        show "Only new images will be indexed."
      end
  end

  def get_unindexed_pics
    @pics_to_index = @aperture.get_unindexed_pics()
    @get_unindexed_thr.invalidate
    puts "@get_unindexed_thr is dead."
    @statusLevel.setMaxValue(@pics_to_index.size)
    @statusLevel.setMinValue(0)
    @statusLevel.setWarningValue(@pics_to_index.size*0.3)
    @statusLevel.setCriticalValue(@pics_to_index.size*0.1)
    @generate_go = true
  end

  def generate_hashes

  if @generate_go && @run

      if @pics_to_index.size != 0

        @count += 1

        row = @pics_to_index.shift

        path = (@aperture.libpath + row.last).gsub(/\\/,'')

      	@viewImage.setImageWithURL(NSURL.fileURLWithPath(path)) if @previewButton.state == 1

        open(path, "r") { |f| @sha1_update_all.newline("update ZRKVERSION set ZRESERVED = '#{Digest::SHA1.hexdigest(f.read)}' where Z_PK = #{row.first}") }

        @aperture.send(@sha1_update_all.commit) if (@count % @save_every).zero?
        @sha1_update_all = MultilineQuery.new if (@count % @save_every).zero?

        @statusLevel.setObjectValue(@pics_to_index.size)

        show "#{@pics_to_index.size} images to index | #{File.basename(path)}"

      else

          @aperture.send(@sha1_update_all.commit)      
          @sha1_update_all = MultilineQuery.new
          @generate_hash_thr.invalidate
          puts "@generate_hashes_thr is dead."
          show "Indexing complete!"
          find_duplicates()     

      end

  end

  end

  def find_duplicates
    show "Indexing complete. Searching for duplicates."
    rows = @aperture.get_duplicates()
    if rows.zero?
      show "Awesome. No duplicates were found."
    else
      show "Done! #{rows} duplicates tagged with '#{@aperture.keyword}'"
    end
    prerun()
  end

  def clean_slate
    @aperture.send("update ZRKVERSION set ZRESERVED = null where Z_PK in (select Z_PK from ZRKVERSION)")
    @clean_slate_thr.invalidate
    puts "@clean_slate_thr is dead."
  end

  def show(msg)
    @statusField.setObjectValue(msg)
  end

end

class Aperture

  attr_reader :libpath, :dbpath, :keyword

  def initialize
    @libpath, @dbpath = find_library()
    @keyword = "xduplicate"
  end

  def setupTables

      res = parse_results(send("select Z_PK from ZRKKEYWORD where ZNAME='#{@keyword}'"))
      if res.empty?
        puts "Adding #{@keyword} into ZRKKEYWORD"
        z_pk = parse_results(send("select Z_PK from ZRKKEYWORD order by Z_PK DESC limit 1")).flatten()
        z_pk = z_pk[0].to_i + 1
        zuuid = Digest::MD5.hexdigest(Time.now.to_f.to_s)
        send("insert into ZRKKEYWORD values(0,#{z_pk},1,9,'#{@keyword}','#{zuuid}',null)")
      end
        
      @zkeyworduuid = parse_results(send("select ZUUID from ZRKKEYWORD where ZNAME='#{@keyword}' limit 1")).flatten().first

      unless @zkeyworduuid.nil?
        return true
      else
        return false
      end

  end

  def get_unindexed_pics
    query = "select v.Z_PK, Path ||'/'|| ImportGroup ||'/'|| FolderName ||'/'|| Filename as Fullpath from ZRKVERSION v join (select ZUUID, ZLIBRARYRELATIVEPATH as Path from ZRKFOLDER) b on (b.ZUUID = v.ZPROJECTUUID) join (select ZUUID, ZNAME as FolderName, ZIMPORTGROUP as ImportGroup from ZRKMASTER) c on (c.ZUUID = v.ZMASTERUUID) join (select ZNAME as Filename, ZMASTERUUID from ZRKFILE) d on (d.ZMASTERUUID = c.ZUUID) where v.Z_PK in (select Z_PK from ZRKVERSION where ZRESERVED is null)"
    parse_results(send(query))
  end

  def get_duplicates
    send("delete from ZRKXKEYWORDVERSION where ZKEYWORDUUID='#{@zkeyworduuid}'")
    rows = parse_results(send("select ZVERSIONID,ZUUID from ZRKVERSION where ZRESERVED in (select ZRESERVED from ZRKVERSION group by ZRESERVED having count(ZRESERVED) > 1)"))
    z_pk = parse_results(send("select Z_PK from ZRKXKEYWORDVERSION order by Z_PK DESC limit 1")).flatten().first.to_i + 1
    rows.each do |row|
      zversionid,zversionuuid = row[0],row[1]
      zuuid = Digest::MD5.hexdigest(Time.now.to_f.to_s)
      send("insert into ZRKXKEYWORDVERSION values (#{z_pk},1,#{zversionid},21,'#{zversionuuid}','#{@zkeyworduuid}','#{zuuid}')")
      z_pk+=1
    end
    return rows.size()
  end

  def send(msg)
    unless msg =~ /^\//
      %x|sqlite3 -list -separator ':::' #{@dbpath} "#{msg}"|
    else
      Open3.popen3("sqlite3 -init #{msg} #{@dbpath}")
    end
  end

  def send_by_file(msg)
    sqldump = ENV['HOME'] + "/Library/Caches/" + Digest::MD5.hexdigest(Time.now.to_f.to_s)
    File.open(sqldump,'w') { |f| f << msg }
    send(sqldump)
  end

  private

  def find_library
    aperture_plist = ENV['HOME'] + '/Library/Preferences/com.apple.Aperture.plist'
    plistdump = ENV['HOME'] + '/Library/Caches/' + 'plistdump.tmp'
    `plutil -convert xml1 -o #{plistdump} #{aperture_plist}`
    relative_lib_path = File.open(plistdump).grep(/aplibrary/).first.match(/>(.+)</).to_a[1]
    fullpath = relative_lib_path =~ /^~/ ? relative_lib_path.gsub(/^~/, ENV['HOME']) : relative_lib_path
    `rm #{plistdump}`
    return fullpath.gsub(/ /,'\ ') + "/", (fullpath + "/Aperture.aplib/Library.apdb").gsub(/ /,'\ ')
  end

  def parse_for_requery(msg)
     msg.split("\n").map! { |e| "'" + e + "'" }.join(',')
  end

  def parse_results(query)
    query.split("\n").map! { |e| e.split(":::") }
  end

end

class MultilineQuery

  attr_reader :query

  def initialize
    @query = "begin; "
  end

  def newline(line)
    @query << " " << line << ";"
  end

  def commit
    return @query + " commit;"
  end

end