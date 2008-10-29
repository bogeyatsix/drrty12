TMP_DIR = "/Library/Caches/"

def marshal(filename,data=nil)
  Dir.chdir(TMP_DIR) do
    if data != nil
      open(filename, "w") { |f| Marshal.dump(data, f) }
    elsif File.exists?(filename)
      open(filename) { |f| Marshal.load(f) }
    end
  end
end

def marshal_destroy(filename)
  Dir.chdir(TMP_DIR) do
  if File.exists?(filename)
    File.delete(filename)
  else
    return "File does not exists."
  end
  end
end

def marshal_clone(data)
  filename = srand.to_s << '.tmp'
  marshal(filename,data)
  h = marshal(filename)
  marshal_destroy(filename)
  return h
end