path = File.dirname(__FILE__)
Dir.entries(path).each { |f| require "#{path}/#{f}" if f !~ /^\./ }