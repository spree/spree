require File.join(File.dirname(__FILE__), '../test_helper.rb')

class HelperMethodsTest < Test::Unit::TestCase
  def setup
    
  end
  
  def test_has_time
    assert( ! CalendarDateSelect.has_time?("January 7, 2007"))
    assert(CalendarDateSelect.has_time?("January 7, 2007 5:50pm"))
    assert(CalendarDateSelect.has_time?("January 7, 2007 5:50 pm"))
    assert(CalendarDateSelect.has_time?("January 7, 2007 16:30 pm"))
  end
  
end