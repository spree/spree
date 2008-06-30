require File.expand_path(File.dirname(__FILE__) + '<%= '/..' * controller_class_nesting_depth %>/../spec_helper')

describe <%= controller_class_name %>Helper do
  
  #Delete this example and add some real ones or delete this file
  it "should be included in the object returned by #helper" do
    included_modules = (class << helper; self; end).send :included_modules
    included_modules.should include(<%= controller_class_name %>Helper)
  end
  
end
