require File.dirname(__FILE__) + '/../spec_helper'

describe CalendarDateSelect::FormHelpers do
  include ActionView::Helpers::FormHelper
  include ActionView::Helpers::JavaScriptHelper
  include ActionView::Helpers::AssetTagHelper
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::FormTagHelper

  include CalendarDateSelect::FormHelpers

  before(:each) do
    @controller = ActionController::Base.new
    @request = OpenStruct.new
    @controller.request = @request

    @model = OpenStruct.new
  end

  describe "mixed mode" do
    it "should not output a time when the value is a Date" do
      @model.start_datetime = Date.parse("January 2, 2007")
      output = calendar_date_select(:model, :start_datetime, :time => "mixed")
      output.should_not match(/12:00 AM/)
    end

    it "should output a time when the value is a Time" do
      @model.start_datetime = Time.parse("January 2, 2007 12:00 AM")
      output = calendar_date_select(:model, :start_datetime, :time => "mixed")
      output.should match(/12:00 AM/)
    end
  end

  it "should render a time when time is passed as 'true'" do
    @model.start_datetime = Date.parse("January 2, 2007")
    output = calendar_date_select(:model, :start_datetime, :time => "true")
    output.should match(/12:00 AM/)
  end

  it "should time_false__model_returns_time__should_render_without_time" do
    @model.start_datetime = Time.parse("January 2, 2007 12:00 AM")
    output = calendar_date_select(:model, :start_datetime)
    output.should_not match(/12:00 AM/)
  end

  it "should _nil_model__shouldnt_populate_value" do
    @model = nil
    output = calendar_date_select(:model, :start_datetime)

    output.should_not match(/value/)
  end

  it "should _vdc__should_auto_format_function" do
    @model.start_datetime = Time.parse("January 2, 2007 12:00 AM")
    output = calendar_date_select(:model,
      :start_datetime,
      :valid_date_check => "date < new Date()"
    )
    output.should include("valid_date_check:function(date) { return(date &lt; new Date()) }")

    output = calendar_date_select(:model,
      :start_datetime,
      :valid_date_check => "return(date < new Date())"
    )
    output.should include("valid_date_check:function(date) { return(date &lt; new Date()) }")
    output = calendar_date_select(:model,
      :start_datetime,
      :valid_date_check => "function(p) { return(date < new Date()) }"
    )
    output.should include("valid_date_check:function(p) { return(date &lt; new Date()) }")
  end

  it "should raise an error if the valid_date_check function is missing a return statement" do
    message = ":valid_date_check function is missing a 'return' statement.  Try something like: :valid_date_check => 'if (date > new(Date)) return true; else return false;'"
    lambda {
      output = calendar_date_select(:model,
        :start_datetime,
        :valid_date_check => "date = 5; date < new Date());"
      )
    }.should raise_error(ArgumentError, message)

    lambda {
      output = calendar_date_select(:model,
        :start_datetime,
        :valid_date_check => "function(p) { date = 5; date < new Date()); }"
      )
    }.should raise_error(ArgumentError, message)
  end

  it "should render the year_range argument correctly" do
    output = calendar_date_select(:model, :start_datetime)
    output.should include("year_range:10")
    output = calendar_date_select(:model, :start_datetime, :year_range => 2000..2010)
    output.should include("year_range:[2000, 2010]")
    output = calendar_date_select(:model, :start_datetime, :year_range => (15.years.ago..5.years.ago))
    output.should include("year_range:[#{15.years.ago.year}, #{5.years.ago.year}]")
  end

  it "should disregard the :object parameter when nil" do
    @model.start_datetime = Time.parse("January 2, 2007 12:00 AM")
    output = calendar_date_select(:model, :start_datetime, :time => true, :object => nil)
    output.should include(CalendarDateSelect.format_date(@model.start_datetime))
  end

  it "should regard :object parameter" do
    @model.start_datetime = Time.parse("January 2, 2007 12:00 AM")
    output = calendar_date_select(:lame_o, :start_datetime, :time => true, :object => @model)
    output.should include(CalendarDateSelect.format_date(@model.start_datetime))
  end

  it "should respect parameters provided in default_options" do
    new_options = CalendarDateSelect.default_options.merge(:popup => "force")
    CalendarDateSelect.stub!(:default_options).and_return(new_options)
    calendar_date_select_tag(:name, "").should include("popup:'force'")
  end

  it "should respect the :image option" do
    output = calendar_date_select_tag(:name, "Some String", :image => "boogy.png")
    output.should include("boogy.png")
  end

  it "should not pass the :image option as a javascript option" do
    output = calendar_date_select_tag(:name, "Some String", :image => "boogy.png")
    output.should_not include("image:")
  end

  it "should use the CSS class calendar_date_select_tag for popup selector icon" do
    output = calendar_date_select_tag(:name, "Some String", :image => "boogy.png")
    output.should include("calendar_date_select_popup_icon")
  end

  describe "calendar_date_select_tag" do
    it "should use the string verbatim when provided" do
      output = calendar_date_select_tag(:name, "Some String")

      output.should include("Some String")
    end

    it "should not render the time when time is false (or nil)" do
      time = Time.parse("January 2, 2007 12:01:23 AM")
      output = calendar_date_select_tag(:name, time, :time => false)

      output.should_not match(/12:01 AM/)
      output.should include(CalendarDateSelect.format_date(time.to_date))
    end

    it "should render the time when :time => true" do
      time = Time.parse("January 2, 2007 12:01:23 AM")
      output = calendar_date_select_tag(:name, time, :time => true)

      output.should include(CalendarDateSelect.format_date(time))
    end

    it "should render the time when :time => 'mixed'" do
      time = Time.parse("January 2, 2007 12:01:23 AM")
      output = calendar_date_select_tag(:name, time, :time => 'mixed')

      output.should include(CalendarDateSelect.format_date(time))
    end
  end
end
