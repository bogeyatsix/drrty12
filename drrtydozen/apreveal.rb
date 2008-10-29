#! /usr/bin/ruby

# A very simple script that enables "Reveal in Finder" in Apple's Aperture
# Create a new Automator Action -> Run Shell Script then copy and paste
# all the following. Then Save As Plugin. To enable the scripts menu in 
# the menubar go to Applescript Utility

require 'rubygems'
require 'rbosa'

class Aperture

    attr_reader :libpath, :dbpath, :images, :libsize

    def initialize
      @libpath, @dbpath = findLibrary()
      unless File.directory?(@libpath) && File.file?(@dbpath)
        raise "Cannot locate library!"
      end
    end

    def findLibrary
      home = ENV['HOME']
      plist = "#{home}/Library/Preferences/com.apple.Aperture.plist"
      lib = File.open(plist).read.split(/aplibrary/)[0].split("\020").last.gsub(/^[^~|\/]+/,'')
      lib = lib.gsub(/^~/,home) << "aplibrary/"
      db = lib + "Aperture.aplib/Library.apdb"
      return lib,db
    end

    def reveal_in_finder(zuuids)
      zuuids = zuuids.collect { |e| "'#{e}'" }.join(",")
      query = "select Path ||'/'|| ImportGroup ||'/'|| FolderName ||'/'|| Filename as Fullpath from ZRKVERSION v join (select ZUUID, ZLIBRARYRELATIVEPATH as Path from ZRKFOLDER) b on (b.ZUUID = v.ZPROJECTUUID) join (select ZUUID, ZNAME as FolderName, ZIMPORTGROUP as ImportGroup from ZRKMASTER) c on (c.ZUUID = v.ZMASTERUUID) join (select ZNAME as Filename, ZMASTERUUID from ZRKFILE) d on (d.ZMASTERUUID = c.ZUUID) where v.ZUUID in (#{zuuids});"
      response = send(query)
      response.split("\n").each do |row|
        path_to_file = "#{@libpath}#{row}".gsub(/"/,'\"')
        path_to_file = File.dirname(path_to_file)
        %x|open "#{path_to_file}"|
      end
    end

    def getPath(i)
      path = @libpath + @fullpath[i]
      return path.gsub(/\\/,'')
    end

    def send(msg)
      %x|sqlite3 -list -separator ':::' #{@dbpath} "#{msg}"|
    end

end

aperture = Aperture.new
bridge = OSA.app('Aperture')

zuuids = bridge.selection.collect { |p| p.id2 }
aperture.reveal_in_finder(zuuids)