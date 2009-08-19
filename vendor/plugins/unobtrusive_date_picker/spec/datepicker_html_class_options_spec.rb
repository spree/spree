require File.dirname(__FILE__) + '/spec_helper'

describe "all date picker form helpers", :shared => true do
   before(:each) do
      @date = Date.parse("March 15, 2007")
      @date_model = stub('DateModel', :date => @date, :id => 1)
   end
   
   after(:each) do
      @date, @date_model = nil
   end
end


describe UnobtrusiveDatePicker, "with :highlight_days option passed a string" do
   it_should_behave_like "all date picker helpers"
   it_should_behave_like "all date picker form helpers"
   
   before(:each) do
      @days = '123'
      @datepicker_html = unobtrusive_date_picker(:date_model, :date, {:highlight_days => @days})
   end
   
   it "should have the correct class" do
      year_id = 'date_model_date'
      year_name = 'date_model[date(1i)]'
      highlight_days = 'highlight-days-' + @days
      
      @datepicker_html.should include_tag(:select, :attributes => {:id => year_id, :name => year_name, :class => "#{highlight_days} split-date"})
   end
   
   after(:each) do
      @days, @datepicker_html = nil
   end
end


describe UnobtrusiveDatePicker, "with :highlight_days option passed an array of symbols" do
   it_should_behave_like "all date picker helpers"
   it_should_behave_like "all date picker form helpers"
   
   before(:each) do
      @days = [:Tuesday, :Wednesday, :Thursday]
      @datepicker_html = unobtrusive_date_picker(:date_model, :date, {:highlight_days => @days})
   end
   
   it "should have the correct class" do
      year_id = 'date_model_date'
      year_name = 'date_model[date(1i)]'
      highlight_days = 'highlight-days-123'
      
      @datepicker_html.should include_tag(:select, :attributes => {:id => year_id, :name => year_name, :class => "#{highlight_days} split-date"})
   end
   
   after(:each) do
      @days, @datepicker_html = nil
   end
end


describe UnobtrusiveDatePicker, "with :highlight_days option passed an empty array" do
   it_should_behave_like "all date picker helpers"
   it_should_behave_like "all date picker form helpers"
   
   before(:each) do
      @datepicker_html = unobtrusive_date_picker(:date_model, :date, {:highlight_days => []})
   end
   
   it "should have the correct class" do
      year_id = 'date_model_date'
      year_name = 'date_model[date(1i)]'
      
      @datepicker_html.should include_tag(:select, :attributes => {:id => year_id, :name => year_name, :class => "split-date"})
   end
   
   after(:each) do
      @datepicker_html = nil
   end
end


describe UnobtrusiveDatePicker, "with :range_low option passed :today" do
   it_should_behave_like "all date picker helpers"
   it_should_behave_like "all date picker form helpers"
   
   before(:each) do
      @datepicker_html = unobtrusive_date_picker(:date_model, :date, {:range_low => :today})
   end
   
   it "should have the correct class" do
      year_id = 'date_model_date'
      year_name = 'date_model[date(1i)]'
      range_low = 'range-low-today'
      
      @datepicker_html.should include_tag(:select, :attributes => {:id => year_id, :name => year_name, :class => "#{range_low} split-date"})
   end
   
   after(:each) do
      @datepicker_html = nil
   end
end


describe UnobtrusiveDatePicker, "with :range_low option passed :tomorrow" do
   it_should_behave_like "all date picker helpers"
   it_should_behave_like "all date picker form helpers"
   
   before(:each) do
      @datepicker_html = unobtrusive_date_picker(:date_model, :date, {:range_low => :tomorrow})
   end
   
   it "should have the correct class" do
      year_id = 'date_model_date'
      year_name = 'date_model[date(1i)]'
      tomorrow = Date.tomorrow.strftime(UnobtrusiveDatePicker::RANGE_DATE_FORMAT)
      range_low = "range-low-#{tomorrow}"
      
      @datepicker_html.should include_tag(:select, :attributes => {:id => year_id, :name => year_name, :class => "#{range_low} split-date"})
   end
   
   after(:each) do
      @datepicker_html = nil
   end
end


describe UnobtrusiveDatePicker, "with :range_high option passed a string" do
   it_should_behave_like "all date picker helpers"
   it_should_behave_like "all date picker form helpers"
   
   before(:each) do
      @range_high = 'March 20, 2020'
      @datepicker_html = unobtrusive_date_picker(:date_model, :date, {:range_high => @range_high})
   end
   
   it "should have the correct class" do
      year_id = 'date_model_date'
      year_name = 'date_model[date(1i)]'
      range_date = Date.parse(@range_high).strftime(UnobtrusiveDatePicker::RANGE_DATE_FORMAT)
      html_class = "range-high-#{range_date}"
      
      @datepicker_html.should include_tag(:select, :attributes => {:id => year_id, :name => year_name, :class => "#{html_class} split-date"})
   end
   
   after(:each) do
      @range_high, @datepicker_html = nil
   end
end


describe UnobtrusiveDatePicker, "with :range_high option passed a Date object" do
   it_should_behave_like "all date picker helpers"
   it_should_behave_like "all date picker form helpers"
   
   before(:each) do
      @range_high = Date.parse('March 20, 2020')
      @datepicker_html = unobtrusive_date_picker(:date_model, :date, {:range_high => @range_high})
   end
   
   it "should have the correct class" do
      year_id = 'date_model_date'
      year_name = 'date_model[date(1i)]'
      range_date = @range_high.strftime(UnobtrusiveDatePicker::RANGE_DATE_FORMAT)
      html_class = "range-high-#{range_date}"
      
      @datepicker_html.should include_tag(:select, :attributes => {:id => year_id, :name => year_name, :class => "#{html_class} split-date"})
   end
   
   after(:each) do
      @range_high, @datepicker_html = nil
   end
end


describe UnobtrusiveDatePicker, "with :range_high passed nil and :range_low option passed an empty string" do
   it_should_behave_like "all date picker helpers"
   it_should_behave_like "all date picker form helpers"
   
   before(:each) do
      @datepicker_html = unobtrusive_date_picker(:date_model, :date, {:range_high => nil, :range_low => ''})
   end
   
   it "should have the correct class" do
      year_id = 'date_model_date'
      year_name = 'date_model[date(1i)]'
      
      @datepicker_html.should include_tag(:select, :attributes => {:id => year_id, :name => year_name, :class => "split-date"})
   end
   
   after(:each) do
      @datepicker_html = nil
   end
end


describe UnobtrusiveDatePicker, "with :disable_days option passed an array of symbols" do
   it_should_behave_like "all date picker helpers"
   it_should_behave_like "all date picker form helpers"
   
   before(:each) do
      @days = [:Saturday, :Sunday]
      @datepicker_html = unobtrusive_date_picker(:date_model, :date, {:disable_days => @days})
   end
   
   it "should have the correct class" do
      year_id = 'date_model_date'
      year_name = 'date_model[date(1i)]'
      disable_days = 'disable-days-56'
      
      @datepicker_html.should include_tag(:select, :attributes => {:id => year_id, :name => year_name, :class => "#{disable_days} split-date"})
   end
   
   after(:each) do
      @days, @datepicker_html = nil
   end
end


describe UnobtrusiveDatePicker, "with :disable_days option passed an empty array" do
   it_should_behave_like "all date picker helpers"
   it_should_behave_like "all date picker form helpers"
   
   before(:each) do
      @datepicker_html = unobtrusive_date_picker(:date_model, :date, {:disable_days => []})
   end
   
   it "should have the correct class" do
      year_id = 'date_model_date'
      year_name = 'date_model[date(1i)]'
      
      @datepicker_html.should include_tag(:select, :attributes => {:id => year_id, :name => year_name, :class => "split-date"})
   end
   
   after(:each) do
      @datepicker_html = nil
   end
end


describe UnobtrusiveDatePicker, "with :no_transparency option set to true" do
   it_should_behave_like "all date picker helpers"
   it_should_behave_like "all date picker form helpers"
   
   before(:each) do
      @datepicker_html = unobtrusive_date_picker(:date_model, :date, {:no_transparency => true})
   end
   
   it "should have the correct class" do
      year_id = 'date_model_date'
      year_name = 'date_model[date(1i)]'
      html_class = 'no-transparency'
      
      @datepicker_html.should include_tag(:select, :attributes => {:id => year_id, :name => year_name, :class => "#{html_class} split-date"})
   end
   
   after(:each) do
      @datepicker_html = nil
   end
end


describe UnobtrusiveDatePicker, "with :no_transparency option set to false" do
   it_should_behave_like "all date picker helpers"
   it_should_behave_like "all date picker form helpers"
   
   before(:each) do
      @datepicker_html = unobtrusive_date_picker(:date_model, :date, {:no_transparency => false})
   end
   
   it "should have the correct class" do
      year_id = 'date_model_date'
      year_name = 'date_model[date(1i)]'
      
      @datepicker_html.should include_tag(:select, :attributes => {:id => year_id, :name => year_name, :class => "split-date"})
   end
   
   after(:each) do
      @datepicker_html = nil
   end
end

