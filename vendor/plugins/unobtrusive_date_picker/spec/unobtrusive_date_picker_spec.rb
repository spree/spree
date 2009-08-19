require File.dirname(__FILE__) + '/spec_helper'

describe "all datetime picker form helpers", :shared => true do
   before(:each) do
      @time = Time.parse("March 15, 2007 2:37PM")
      @datetime_model = stub('DateTimeModel', :datetime => @time, :id => 2)
   end
   
   after(:each) do
      @time, @date_time_model = nil
   end
end

describe UnobtrusiveDatePicker, "with a stub ActiveRecord object" do
   it_should_behave_like "all date picker helpers"
   it_should_behave_like "all datetime picker form helpers"
   
   before(:each) do
      @datepicker_html = unobtrusive_datetime_picker(:datetime_model, :datetime)
   end
   
   it "should select the year from model object attribute" do
      year_id = 'datetime_model_datetime'
      year_name = 'datetime_model[datetime(1i)]'
      
      @datepicker_html.should include_tag(:select, :attributes => {:id => year_id, :name => year_name, :class => 'split-date'}, 
                                                   :child => {:tag => 'option', 
                                                              :attributes => {:value => @time.year.to_s, :selected => 'selected'},
                                                              :content => @time.year.to_s})
   end
   
   it "should select the month from model object attribute" do
      month_id = 'datetime_model_datetime-mm'
      month_name = 'datetime_model[datetime(2i)]'
      
      @datepicker_html.should include_tag(:select, :attributes => {:id => month_id, :name => month_name}, 
                                                   :child => {:tag => 'option', 
                                                              :attributes => {:value => @time.month.to_s, :selected => 'selected'},
                                                              :content => Date::MONTHNAMES[@time.month]})
   end
   
   it "should select the day from model object attribute" do
      day_id = 'datetime_model_datetime-dd'
      day_name = 'datetime_model[datetime(3i)]'
      
      @datepicker_html.should include_tag(:select, :attributes => {:id => day_id, :name => day_name}, 
                                                   :child => {:tag => 'option', 
                                                              :attributes => {:value => @time.day.to_s, :selected => 'selected'},
                                                              :content => @time.day.to_s})
   end
   
   it "should select the hour from model object attribute" do
      hour_id = 'datetime_model_datetime_4i'
      hour_name = 'datetime_model[datetime(4i)]'
      
      @datepicker_html.should include_tag(:select, :attributes => {:id => hour_id, :name => hour_name}, 
                                                   :child => {:tag => 'option', 
                                                              :attributes => {:value => sprintf("%02d", @time.strftime("%I").to_i), :selected => 'selected'},
                                                              :content => sprintf("%02d", @time.strftime("%I").to_i)})
   end
   
   it "should select the minute from model object attribute" do
      minute_id = 'datetime_model_datetime_5i'
      minute_name = 'datetime_model[datetime(5i)]'
      
      @datepicker_html.should include_tag(:select, :attributes => {:id => minute_id, :name => minute_name}, 
                                                   :child => {:tag => 'option', 
                                                              :attributes => {:value => @time.strftime("%M"), :selected => 'selected'},
                                                              :content => @time.strftime("%M")})
   end
   
   it "should select the meridian from model object attribute" do
      meridian_id = 'datetime_model_datetime_7i'
      meridian_name = 'datetime_model[datetime(7i)]'
      
      @datepicker_html.should include_tag(:select, :attributes => {:id => meridian_id, :name => meridian_name}, 
                                                   :child => {:tag => 'option', 
                                                              :attributes => {:value => get_meridian_integer(@time.strftime("%p")), :selected => 'selected'},
                                                              :content => @time.strftime("%p")})
   end
   
   after(:each) do
      @datepicker_html = nil
   end
   
end


describe UnobtrusiveDatePicker, "with a minute step and month numbers options specified" do
   it_should_behave_like "all date picker helpers"
   it_should_behave_like "all datetime picker form helpers"
   
   before(:each) do
      @step = 15
      @datepicker_html = unobtrusive_datetime_picker(:datetime_model, :datetime, {:use_month_numbers => true, :minute_step => @step})
   end
   
   it "should use month numbers for option text" do
      month_id = 'datetime_model_datetime-mm'
      month_name = 'datetime_model[datetime(2i)]'
      
      1.upto(12) do |month|
         @datepicker_html.should include_tag(:select, :attributes => {:id => month_id, :name => month_name}, 
                                                      :child => {:tag => 'option', 
                                                                 :attributes => {:value => month.to_s},
                                                                 :content => month.to_s})
      end
   end
   
   it "should select the minute from model object attribute" do
      minute_id = 'datetime_model_datetime_5i'
      minute_name = 'datetime_model[datetime(5i)]'
      
      
      @datepicker_html.should include_tag(:select, :attributes => {:id => minute_id, :name => minute_name}, 
                                                   :children => {:count => 4, :only => {:tag => 'option'}})
      (0..59).step(@step) do |minute|
         @datepicker_html.should include_tag(:select, :attributes => {:id => minute_id, :name => minute_name}, 
                                                      :child => {:tag => 'option', 
                                                                 :attributes => {:value => sprintf("%02d", minute)},
                                                                 :content => sprintf("%02d", minute)})
      end
   end
   
   after(:each) do
      @datepicker_html = nil
   end
   
end
