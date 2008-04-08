require File.dirname(__FILE__) + '/abstract_test.rb'
require 'paging_enumerator'

class PagingEnumeratorTest < Test::Unit::TestCase
  
  def test_should_count_pages_correctly
    assert_equal 4, enum(page_size, total_size).page_count
  end
  
  def test_should_page
    assert_equal(
      (1..total_size).to_a, 
      iterate(enum(page_size, total_size, true)) # iterate enum
    )
  end
  
  def test_should_page_manually
    assert_equal(
      (1..page_size).to_a, 
      iterate(enum(page_size, total_size)) # iterate manual_paging enum
    )
  end
  
  def test_should_move_to_next_page
    enum = enum(page_size, total_size)

    # Iterate the enumeration and inspect the results
    # and manually move to the next page
    iterate(enum)
    enum.next_page!

    # Iterate the next page and verify that the enum
    # returned the results from the next page
    assert_equal(
      ((page_size + 1)..(page_size * 2)).to_a, 
      iterate(enum)
    )
   end
  
  def test_should_not_move_to_next_page
    enum = enum(page_size, total_size)
    
    # Iterate the enumeration and inspect the results
    assert_equal (1..page_size).to_a, iterate(enum)
    
    # Verify that we are able to iterate the same page twice in a row
    assert_equal (1..page_size).to_a, iterate(enum)
  end
  
  def test_should_move_to_last_page
    enum = enum(page_size, total_size)

    # Iterate the enumeration and inspect the results
    # then manually move to the last page
    iterate(enum)
    enum.last_page!

    assert_equal([10], iterate(enum))
   end
  
  def test_should_move
    enum = enum(page_size, total_size)
    assert_equal(1, enum.page)
    enum.move!(2)
    assert_equal(2, enum.page)
    assert_equal(1, enum.first_page)
    start_val = (page_size - 1) * 2
    end_val = (page_size - 1) * 3
    assert_equal (start_val..end_val).to_a, iterate(enum)
  end
  
  def test_move_should_respect_upper_boundary
    enum = enum(page_size, total_size)
    assert_equal(1, enum.page)
    enum.move!(100) # try moving to really high page
    assert_equal(enum.last_page, enum.page)
  end
  
  def test_move_should_respect_lower_boundary
    enum = enum(page_size, total_size)
    assert_equal(1, enum.page)
    enum.move!(-100) # try moving to low page
    assert_equal(enum.first_page, enum.page)
  end
  
  def test_should_raise_on_move
    enum = enum(page_size, total_size, true)
    assert_equal(1, enum.page)
    assert_raises(ArgumentError) { enum.move!(2) }
  end
  
  def test_next_page_should_respect_upper_boundar
    enum = enum(page_size, total_size)
    enum.last_page!
    assert_equal enum.last_page, enum.page
    enum.next_page!
    assert_equal enum.last_page, enum.page
  end
  
  def test_previous_page_should_respect_upper_boundar
    enum = enum(page_size, total_size)
    enum.first_page!
    assert_equal enum.first_page, enum.page
    enum.previous_page!
    assert_equal enum.first_page, enum.page
  end
  
  def test_should_handle_zero_page_size
    enum(0, 1).each {}
  end
  
  def iterate(enum)
    results = []
    first_page = enum.first_page
    enum.each do |e|
      # Verify that the enum.first_page does not change as we iterate
      assert_equal(first_page, enum.first_page)
      # Verify that the enum.page is correct for the current enum value 
      assert_equal(((e - 1) / enum.page_size) + 1, enum.page)
      results << e 
    end
    results
  end
  
  # Build the PagingEnumerable with a certain page size and
  # total number of elements. Set up a callback that pages
  # integers in range 1..total_size. 
  def enum(page_size, total_size, auto = nil)
    PagingEnumerator.new(page_size, total_size, auto) do |page|
      lower = page == 1 ? 0 : (page - 1) * page_size
      upper = lower + page_size - 1
      (1..total_size).to_a[lower..upper]
    end
  end
  
  def page_size
    3
  end
  
  def total_size
    10
  end
end