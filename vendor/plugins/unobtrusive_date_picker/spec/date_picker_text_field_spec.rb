require File.dirname(__FILE__) + '/spec_helper'

describe "a unobtrusive_date_text_picker with a stub ActiveRecord object" do
  it_should_behave_like "all date picker helpers"

  before(:each) do
    @date = Date.parse("March 15, 2007")
    @date_model = stub('DateModel', :date => @date, :id => 1)
    @datepicker_html = unobtrusive_date_text_picker(:date_model, :date, :format => 'd-m-y', :divider => 'dash')
  end
  
  it "should have all the correct classes and attributes" do
    @datepicker_html.should selector_tag("input#date_model_date.format-d-m-y.divider-dash[type='text'][value='15-03-2007']")
  end
  
  after(:each) do
    @date, @date_model, @datepicker_html = nil
  end
end

describe "a unobtrusive_date_text_picker_tag with a date object" do
  it_should_behave_like "all date picker helpers"

  before(:each) do
    @date = Date.parse("March 15, 2007")
    @datepicker_html = unobtrusive_date_text_picker_tag(:date_value, @date, :divider => '.')
  end
  
  it "should have all the correct classes and attributes" do
    @datepicker_html.should selector_tag("input#date_value.format-m-d-y.divider-dot[type='text'][value='03.15.2007']")
  end
  
  after(:each) do
    @date, @datepicker_html = nil
  end
end

describe "a unobtrusive_date_text_picker with a ActiveRecord attribute with a nil value" do
  it_should_behave_like "all date picker helpers"

  before(:each) do
    @date = nil
    @date_model = stub('DateModel', :date => @date, :id => 1)
    @datepicker_html = unobtrusive_date_text_picker(:date_model, :date, :format => 'd-m-y', :divider => 'dash')
  end

  it "should have all the correct classes and attributes" do
    @datepicker_html.should selector_tag("input#date_model_date.format-d-m-y.divider-dash[type='text'][value='']")
  end

  after(:each) do
    @date, @date_model, @datepicker_html = nil
  end
end