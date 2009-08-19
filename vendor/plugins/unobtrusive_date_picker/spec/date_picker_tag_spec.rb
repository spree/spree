require File.dirname(__FILE__) + '/spec_helper'

describe UnobtrusiveDatePicker, "with no data passed to tag helper" do
   it_should_behave_like "all date picker helpers"
   
   before(:each) do
      @default_id = ActionView::Helpers::DateTimeSelector::DEFAULT_PREFIX
      @date = Date.today
      @datepicker = unobtrusive_date_picker_tags(nil, {:include_blank => true})
   end
   
   it "should have default prefix for year id" do
      default_name = @default_id + "[#{UnobtrusiveDatePicker::DATEPICKER_DEFAULT_NAME_ID_SUFFIXES[:year][:name]}]"
      @datepicker.should include_tag(:select, :attributes => {:id => @default_id, :name => default_name})
   end
   
   it "should have 'split-date' in class on year" do
      default_name = @default_id + "[#{UnobtrusiveDatePicker::DATEPICKER_DEFAULT_NAME_ID_SUFFIXES[:year][:name]}]"
      @datepicker.should include_tag(:select, :attributes => {:class => 'split-date', :name => default_name})
   end
   
   it "should have default prefix and 'mm' on month id" do
      month_id = @default_id + '-mm'
      month_name = @default_id + "[#{UnobtrusiveDatePicker::DATEPICKER_DEFAULT_NAME_ID_SUFFIXES[:month][:name]}]"
      @datepicker.should include_tag(:select, :attributes => {:id => month_id, :name => month_name})
   end
   
   it "should have default prefix and 'dd' on day id" do
      day_id = @default_id + '-dd'
      day_name = @default_id + "[#{UnobtrusiveDatePicker::DATEPICKER_DEFAULT_NAME_ID_SUFFIXES[:day][:name]}]"
      @datepicker.should include_tag(:select, :attributes => {:id => day_id, :name => day_name})
   end
   
   it "should include blank selected option for all selects" do
      ids = []
      ids << @default_id + '-dd'
      ids << @default_id + '-mm'
      ids << @default_id
      
      ids.each do |id|
         @datepicker.should include_tag(:select, :attributes => {:id => id}, :child => {:tag => 'option', :attributes => {:value => ''}, :content => ''})
      end
   end
   
   it "should use full month names for option text" do
      month_id = @default_id + '-mm'
      
      1.upto(12) do |month_number|
         @datepicker.should include_tag(:select, :attributes => {:id => month_id}, :child => {:tag => 'option', :attributes => {:value => month_number.to_s}, :content => Date::MONTHNAMES[month_number]})
      end
   end
   
   it "should have current year +/-5 years" do
      start_year, end_year = @date.year - 5, @date.year + 5
      
      start_year.upto(end_year) do |year|
         @datepicker.should include_tag(:select, :attributes => {:id => @default_id}, :child => {:tag => 'option', :attributes => {:value => year.to_s}, :content => year.to_s})
      end
   end
   
   after(:each) do
      @date, @datepicker = nil
   end
   
end


describe UnobtrusiveDatePicker, "with specific date and options passed to tag helpers" do
   it_should_behave_like "all date picker helpers"
   
   before(:each) do
      @id = "date_published"
      @date = Date.parse("March 15, 2007")
      @start_year = 1945
      @end_year = Date.today.year
      @datepicker = unobtrusive_date_picker_tags(@date, {:use_short_month => true, :start_year => @start_year, :end_year => @end_year}, {:id => @id})
   end
   
   it "should have a year select tag with options that start with the start date and end with the end date" do
     @start_year.upto(@end_year) do |year|
         @datepicker.should include_tag(:select, :attributes => {:id => @id}, :child => {:tag => 'option', :attributes => {:value => year.to_s}, :content => year.to_s})
      end
   end
   
   it "should have only the options for the range of years" do
      total_options = (@start_year..@end_year).entries.size
      @datepicker.should include_tag(:select, :attributes => {:id => @id}, :children => {:count => total_options, :only => {:tag => 'option'}})
   end
   
   it "should include only options for months 1 to 12" do
      month_id = @id + '-mm'
      
      1.upto(12) do |month|
         @datepicker.should include_tag(:select, :attributes => {:id => month_id}, :child => {:tag => 'option', :attributes => {:value => month.to_s}})
      end
      
      @datepicker.should include_tag(:select, :attributes => {:id => month_id}, :children => {:count => 12, :only => {:tag => 'option'}})
   end
   
   it "should include only options for days 1 to 31" do
      day_id = @id + '-dd'
      
      1.upto(31) do |day|
         @datepicker.should include_tag(:select, :attributes => {:id => day_id}, :child => {:tag => 'option', :attributes => {:value => day.to_s}, :content => day.to_s})
      end
      
      @datepicker.should include_tag(:select, :attributes => {:id => day_id}, :children => {:count => 31, :only => {:tag => 'option'}})
   end
   
   it "should use short month names for option text" do
      month_id = @id + '-mm'
      
      1.upto(12) do |month_number|
         @datepicker.should include_tag(:select, :attributes => {:id => month_id}, :child => {:tag => 'option', :attributes => {:value => month_number.to_s}, :content => Date::ABBR_MONTHNAMES[month_number]})
      end
   end
   
   after(:each) do
      @id, @date, @datepicker, @start_year, @end_year = nil
   end
   
end
