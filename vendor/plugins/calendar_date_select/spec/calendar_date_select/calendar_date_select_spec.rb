require File.dirname(__FILE__) + '/../spec_helper'

describe CalendarDateSelect do
  it "should detect presence of time in a string" do
    CalendarDateSelect.has_time?("January 7, 2007").should == false
    CalendarDateSelect.has_time?("January 7, 2007 5:50pm").should == true
    CalendarDateSelect.has_time?("January 7, 2007 5:50 pm").should == true
    CalendarDateSelect.has_time?("January 7, 2007 16:30 pm").should == true
    
    CalendarDateSelect.has_time?(Date.parse("January 7, 2007 3:00 pm")).should == false
    CalendarDateSelect.has_time?(Time.parse("January 7, 2007 3:00 pm")).should == true
    CalendarDateSelect.has_time?(DateTime.parse("January 7, 2007 3:00 pm")).should == true
  end
end
