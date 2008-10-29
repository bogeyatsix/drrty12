=begin DOCUMENTATION & EXAMPLES

  # ------------- GoogleSearch ---------------

  # Query google with the terms "auto insurance". Initialization
  # expects an array of terms, *not* a string!

    searchTerms = %w|auto insurance|
    googlePage = GoogleSearch.new(searchTerms)

  # Every google page has 3 'blocks' of results we are interested
  # in: the top ad listings, the side ad listings, and the organic
  # listings. We access them via #top #side and #org e.g.

    googlePage.org

  # returns an array of results in the organic listings. To get
  # the title of the third listing in the organic results.

    googlePage.org[2][:title]

  # You can also access each listing's :url and :description
  # Before that, you can check if any results were returned via
  
    googlePage.hits # e.g googlePage.hits.zero?
  
  # or you can check if any of the 'blocks' are empty. In the case
  # where there are organic results but no advertisers.

    googlePage.side.empty?


  # ------------- InsightsSearch ---------------

  # Query Google's Insights for Search with the terms "auto insurance".
  
    searchTerms = %w|auto insurance|
    insightsPage = InsightsSearch.new(searchTerms)
  
  # Before continuing, best to download a copy of the CSV from the site
  # to see what tables are available. Each table in the CSV is accessible
  # via a method call for the name of the table. E.g. for the table
  # "Top rising searches..." and "Top Cities for..."
  
    insightsPage.top_rising_searches
    insightsPage.top_cities

  # Because the class uses #method_missing to find the name of the tables
  # via Regex matching, the two method calls above can be simplified to:

    insightsPage.rising
    insightsPage.cities

  # The only caveat is the "Top Searches related to..." table. If you call:
  
    insightsPage.top_searches
    
  # it will return *both* the "Top Searches" table and the "Top rising 
  # searches" table. This is due to Regex matching. To get around this
  # and to get to "Top Searches", a modification is made in the CSV
  # after the query is returned, so we can call instead:
  
    insightsPage.top_related_searches
    
  # or more simply:
  
    insightsPage.related_searches

  # To query TWO OR MORE TERMS simultaneously, e.g. "auto insurance" 
  # and "gossip girl", you would init the search with:
  
    searchTerms = ["auto insurance","gossip girl"]
    insightsPage = InsightsSearch.new(searchTerms)

  # All the methods above remain the same, execept, instead of returning 
  # a table (one array), it will wrap the tables in a multi-dimensional 
  # array. E.g.
  
    insightsPage.rising
    insightsPage.rising.size #=> 2

  # Where each member of the array:

    insightsPage.rising.first #=> "Top rising searches related to auto insurance"
    insightsPage.rising.last  #=> "Top rising searches related to gossip girl"
    
  # Thanks to #method_missing and Regex magic, the faster way to get to each of 
  # these tables would be to include the term itself in the method name e.g.
  
    insightsPage.rising_gossip_girl #=> "Top rising searches related to gossip girl"
  
  # One caveat of the multiterm search is that if you call a very 
  # broad-scope search such as:

    insightsPage.top_searches

    insightsPage.top_searches.size #=> 4

  # In this case of 2 terms, 4 arrays are returned where every alternating table:

    insightsPage.searches[0] & insightsPage.searches[2]

    #=> "Top Related Searches related to auto insurance" & "Top rising searches for auto insurance"

  # Respectively:

    insightsPage.searches[1] & insightsPage.searches[3]

    #=> "Top Related Searches related to gossip girl" & "Top rising searches for auto insurance"

=end

require 'rubygems'
require 'hpricot'
require 'open-uri'
require 'cgi'

DEBUG = false

class GoogleSearch

  def initialize(terms)

    # terms expect an array ['hello','world']

    q = "http://www.google.com/search?adtest=on&hl=en&safe=off&host=google.com&gl=US&q=#{terms.join("+")}"

    puts "GOOGLE:#{q}" if DEBUG

    doc = Hpricot open(q)

    # There are 3 'blocks' of results: the top ad listings, the side ad listings,
    # and the organic search results. Each 'block' is wrapped in a div with their
    # respective ids. Each listing within the blocks are wrapped in <li>. We extract
    # the <li> and then conform/collect them into hash objects with 3 properties
    # of 'Title','Description','Link'.

    @page = {}

    unless doc.search("#tads").empty?
      @page[:top] = doc.search("#tads").search("li").collect { |e| makeTopUnit(e) }
    else
      @page[:top] = []
    end

    unless doc.search("#mbEnd").empty?
      @page[:side] = doc.search("#mbEnd").search("li").collect { |e| makeSideUnit(e) }
    else
      @page[:side] = []
    end

    unless doc.search("#ssb > p b").empty?
      @page[:org] = doc.search("#res").search("li").collect { |e| makeOrgUnit(e) }
      @page[:hits] = doc.search("#ssb > p b")[2].innerText.gsub(/,/,'').to_i
    else
      @page[:org] = []
      @page[:hits] = 0
    end

  end
  
  def makeSideUnit(elem)
    h = {}
    # Within the <li>, the *only* <a> is the big blue title itself.
    h[:title] =  elem.search("a").innerHTML
    # The grey description falls between <h3> title above and the <cite> below
    h[:description] = elem.innerHTML.match(/<\/h3>(.+)<cite>/)[1]
    # The green url is wrapped in a <cite>
    h[:url] = elem.search("cite").innerHTML
    return h
  end

  def makeTopUnit(elem)
    h = {}
    # Within the <li>, the *only* <a> is the big blue title itself.
    h[:title] = elem.search("a").innerHTML
    # The grey description falls at the vey end after the <cite> to the end of line
    h[:description] = elem.innerHTML.match(/<\/cite>(.+)$/)[1]
    # The green url is wrapped in a <cite>
    h[:url] = elem.search("cite").innerHTML
    return h
  end

  def makeOrgUnit(elem)
    h = {}
    # Within the <li>, the *only* <a> is the big blue title itself.
    h[:title] = elem.search("a").innerHTML
    # Every <li> in the organic listings have two <span> elements, the first
    # contains the grey description, the second is the green colored url.
    # Make an array of them and collect back only the innerHTML of each.
    h[:description], h[:url] = Array.new(elem.search("//span")).collect { |e| e.innerHTML }
    return h
  end

  def method_missing(m)
    # More efficient way of not having to create accessor methods for each
    # key within page. Call with resultPage.{top|side|org}
    @page[m].collect { |h| h.merge(h) { |k,o,n| n = cleanText(o) } }
  end

  def all
    [] << top << side << org
  end

  def hits
    @page[:hits]
  end

  def cleanText(str)
      h = str.gsub(/&nbsp;/,'') # Clean the description
      h = h.gsub(/<b>\.\.\.<\/b>/,'') # Remove trailing dots
      h = h.gsub(/<br ?\/?>/,'') # Remove line breaks
      h = CGI::unescapeHTML(h)
      h = h.strip
      h
  end

end

class InsightsSearch

  def initialize(terms)
    
    # terms expect an array ['hello world'] or for multiples ['hello world','foo bar']

    terms = terms.collect { |t| t.gsub(/ /,"%20") }
    terms = terms.join("%2C")

    q = "http://www.google.com/insights/search/overviewReport?q=#{terms}&cmpt=q&content=1&export=1"

    puts "INSIGHTS:#{q}" if DEBUG

    # Read in the CSV via open-uri, but we cheat and change 'Top Searches' to 'Top Related Searches'
    # in order for method_missing to call #top_related_searches & #top_rising_searches respectively

    doc = open(q).read.gsub(/Top Searches/,"Top Related Searches")

    # Assume that two line breaks demarcate a table boundary. Then assume every newline
    # within each table is a new row.
    
    @tables = doc.split("\n\n").collect { |e| e.split("\n") }

    # Remove empty tables if any

    @tables.delete_if { |table| table.empty? }

    # Remove empty rows/elements if any

    @tables.each { |table| table.delete_if { |row| row.empty? } }

    # At this point, the first element of each table e.g. @tables[0][0] is the Label of the table.

  end
  
  def method_missing(m)
    # More efficient way of not having to create accessor methods for each table
    # within page. Tables are accessible by calling the name of the table as a method
    # e.g. #top_related_searches, #top_rising_searches, #top_cities_gossip_girl
    reStr = m.to_s.gsub('_','.+')
    re = Regexp.new(reStr,'i')
    resultTables = @tables.find_all { |table| table[0] =~ re }
    return resultTables.size == 1 ? resultTables[0] : resultTables
  end
  
end

