# An enumerable that iterates through "pages" of objects.
# A page is loaded by the block callback provided to the initializer.
#
#   pe = PagingEnumerable.new(25, 593) do |current_page|
#     # return all results for the current_page!
#   end
#   pe.each { |result| puts result }
#
# Specify auto = true if you want the enumerator
# to iterate over all items rather than just those on the
# current page. If this option is enabled you may skip to the 
# next page by invoking the next_page! method, or you may skip 
# to any page using the move!(page) method.
# 
# The callback may return an Enumerable containing the results
# for the current page, or an object if only one result is 
# available for the current page.
#
# Author::    Alex Wolfe
# Copyright:: Copyright (c) 2006 Alex Wolfe
# License::   Distributes under the same terms as Ruby
# More Info:: http://cardboardrocket.com
#
class PagingEnumerator
  include Enumerable

  attr_accessor :results, :page, :first_page, :last_page, :stop_page, :page_size, :page_count, :size, :auto

  def initialize(page_size, size, auto = false, page = 1, first_page=page, &callback)
    self.page = page.to_i
    self.page_size = page_size.to_i
    self.size = size.to_i
    self.auto = auto
    self.first_page = first_page.to_i
    self.last_page = page_count.to_i
    self.stop_page = auto ? last_page : self.page
    @callback = callback
  end
  
  def each
    early_termination = false
    while page <= stop_page && !early_termination
      load_page
      if results.respond_to?(:each)
        results.each { |r| yield r }
      else
        yield results
      end
      self.page = self.page + 1
      if (results.respond_to?(:size) && results.size < page_size)
        early_termination = true
      end
    end
    # force usage of next_page method
    self.page = self.page - 1
    self
  end
  
  def move!(page)
    raise ArgumentError, "manually moving pages is only supported when auto paging is disabled" if auto
    if page < self.first_page
      self.page = first_page
    elsif page > self.last_page
      self.page = last_page
    else
      self.page = page
    end
    self.stop_page = page
  end
  
  def page_exists?(page)
    page >= self.first_page && page <= self.last_page
  end
  
  def first_page!
    move!(first_page)
  end
  
  def last_page!
    move!(last_page)
  end
  
  # Move to the next page if auto paging is disabled.
  def next_page!
    move!(next_page) if next_page?
  end
  
  def next_page?
    next_page ? true : false
  end
  
  def next_page
    page >= page_count ? nil : page + 1
  end
  
  # Move to the previous page if auto paging is disabled.
  def previous_page!
    move!(previous_page) if previous_page?
  end
  
  def previous_page?
    previous_page ? true : false
  end
  
  def previous_page
    page == first_page ? nil : page - 1
  end
  
  def first_item
    ((self.page-1) * self.page_size) + 1
  end
  
  def last_item
    [self.page * self.page_size, self.size].min
  end

  # How many pages are available?
  def page_count
    @page_count ||= (empty? or page_size == 0) ? 1 : (q, r = size.divmod(page_size); r == 0 ? q : q + 1)
  end
  
  def empty?
    size == 0
  end
  
  # Get the results as an array. If the enumerator is not using :auto, this array
  # will contain just the current page. Otherwise, this method will iterate all pages
  # and return them as an array.
  def to_a
    array = []
    each { |e| array << e }
    array
  end
  
  def to_xml(options = {})
    to_a.to_xml(options)
  end  

  # Load the next page using the callback
  def load_page
    raise "Cannot load page because callback is not available. Has this enumerator been serialized?" unless @callback
    self.results = @callback.call(page)
  end
  
  def _dump(depth)
    load_page
   Marshal.dump([results, page_size, size, false, page, first_page])
  end
  
  def PagingEnumerator._load(str)
    params = Marshal.load(str)
    results = params.shift
    e = PagingEnumerator.new(*params)
    e.results = results
    e
  end
    
end
