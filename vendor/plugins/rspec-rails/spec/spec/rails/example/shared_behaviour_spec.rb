require File.dirname(__FILE__) + '/../../../spec_helper'

describe "A shared view example_group", :shared => true do
  it "should have some tag with some text" do
    response.should have_tag('div', 'This is text from a method in the ViewSpecHelper')
  end
end

describe "A view example_group", :type => :view do
  it_should_behave_like "A shared view example_group"
  
  before(:each) do
    render "view_spec/implicit_helper"
  end
end
  
