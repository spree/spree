require File.expand_path(File.dirname(__FILE__) + '<%= '/..' * controller_class_nesting_depth %>/../spec_helper')

describe <%= class_name %> do
  before(:each) do
    @<%= file_name %> = <%= class_name %>.new
  end

  it "should be valid" do
    @<%= file_name %>.should be_valid
  end
end
