require 'zlib'
require 'digest'
require 'enumerator'
require 'cgi'

class String

  def deflate # USAGE: Gzips a string. Call #inflate to unGzip. E.g. "Stringy text".deflate.inflate == "Stringy text"
    Zlib::Deflate.deflate(self)
  end
  
  def inflate # USAGE: UnGzips an encoded string called with "Stringy text".deflate ibid.
    Zlib::Inflate.inflate(self)
  end

  def digest(md5=false) # USAGE: Returns SHA1 checksum for a string, if called with true, returns MD5 instead
    md5 ? Digest::MD5.hexdigest(self) : Digest::SHA1.hexdigest(self)
  end

  def basename  # USAGE: Convenience method, similar to calling File.basename on a path
    File.basename(self,'.*')
  end

  def ext # USAGE: Assuming the string is a path to a file, returns the extension
    File.basename(self).match(/\.(.+)/)[1]
  end

  def style(*args) # USAGE: "Some stringy text".style(:red,:bold,:underline)
    h = {}
    h[:bold]      = "\e[1m:::\e[0m"
    h[:underline] = "\e[4m:::\e[0m"
    h[:blink]     = "\e[5m:::\e[0m"
    h[:reverse]   = "\e[7m:::\e[0m"
    h[:black]     = "\e[30m:::\e[0m" 
    h[:red]       = "\e[31m:::\e[0m"
    h[:green]     = "\e[32m:::\e[0m"
    h[:yellow]    = "\e[33m:::\e[0m"
    h[:blue]      = "\e[34m:::\e[0m"
    h[:magenta]   = "\e[35m:::\e[0m"
    h[:cyan]      = "\e[36m:::\e[0m"
    h[:white]     = "\e[37m:::\e[0m"
    args.inject(self) { |s,arg| h[arg].gsub(/:::/,s) }
  end

  def to_url
    CGI::escape(self)
  end

  def from_url
    CGI::unescape(self)
  end

end

class File

  def digest(md5=false) # USAGE: returns SHA1 checksum of a file, if called with true, returns MD5 instead
    md5 ? Digest::MD5.hexdigest(self.read) : Digest::SHA1.hexdigest(self.read)
  end

end

module Enumerable
  
  def simult  # USAGE: Iterates through Enumerable object simultaneously. E.g. url_array.simult.each { |url| open(url) }
    if block_given?
      collect { |e| Thread.new { yield(e) } }.each { |t| t.join } 
      self 
    else
      enum_for :simult
    end 
  end 

  def collect # USAGE: Delegate method for simultaneuous iteration through an Enumerable
     results = [] 
     each_with_index { |e, i| results[i] = yield(e) } 
     results 
  end 

  def each_with_index # USAGE: Delegate method for simultaneuous iteration through an Enumerable
     i = -1 
     each { |e| yield e, i += 1 } 
  end 

  # By default, #delete_if works as such that:
  # a = [1,2,3]
  # b = a.delete_if { |x| x == 1 }
  #=> b == [2,3] & a == [2,3]
  # What if you want to know what elements were deleted? This is where delete_fi comes in.
  # a = [1,2,3]
  # b = a.delete_fi { |x| x == 1 }
  #=> b == [1] & a == [2,3]
  
  def delete_fi
    x = select { |v| v if yield(v) }
    delete_if { |v| v if yield(v) }
    x.empty? ? nil : x
  end

end

class Array

  def add(w)  # USAGE: Mainly for efficient storing of constantly used strings. Interns the string, puts it into a 'set-like' array.
    if w.respond_to?('intern')
      self.push(w.downcase.intern)
      self.uniq!
    else
      nil
    end
  end

  def swap(o,n) # USAGE: Swap old element (o) with new element (n) in the array
    pos = []
    self.each_with_index { |e,i| pos.push(i) if e == o }
    pos.each { |i| self[i] = n }
  end

end

class Float

  def roundf(decimel_places)
      temp = self.to_s.length
      sprintf("%#{temp}.#{decimel_places}f",self).to_f
  end

end

class Integer

  # Mainly for easy reading e.g. 10000 -> 10,000 or 1000000 -> 100,000
  # Call with argument to specify delimiter.

  def delimit(delimiter=',')
    st = self.to_s.reverse
    r = ""
    max = if st[-1].chr == '-'
      st.size - 1
    else
      st.size
    end
    if st.to_i == st.to_f
      1.upto(st.size) {|i| r << st[i-1].chr ; r << delimiter if i%3 == 0 and i < max}
    else
      start = nil
      1.upto(st.size) {|i|
        r << st[i-1].chr
        start = 0 if r[-1].chr == '.' and not start
        if start
          r << delimiter if start % 3 == 0 and start != 0  and i < max
          start += 1
        end
      }
    end
    r.reverse
  end

end

class Hash

  def collect
    x = select { |k,v| yield(k,v) }
    h = x.inject({}) { |h,v| h.update x.first => x.last }
    h
  end

end











