#! /usr/bin/ruby
# Searches for rapidshare links in given url, only looks at <a>
# USAGE: from command line $rapidget http://www.someurl.com/page1.htm
# Prints out rapidshare links for east copy & paste, also copies to
# clipboard for convenience

require 'rubygems'
require 'hpricot'
require 'open-uri'
require 'beckett/ext1'

ARGV.each do |arg|

	clipboard = []
	doc = Hpricot(open(arg))
	doc.search("a").each do |a|
		if a['href'] =~ /rapidshare/
			puts a['href'].style(:red)
			clipboard.push(a['href'])
		end
	end

  clipboard = clipboard.join("\n")

  %x{ruby -e "puts '#{clipboard}'" | pbcopy }

end