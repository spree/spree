require File.dirname(__FILE__) + '<%= '/..' * class_nesting_depth %>/../spec_helper'

describe <%= class_name %>Controller do

<% if actions.empty? -%>
  #Delete this example and add some real ones
<% else -%>
  #Delete these examples and add some real ones
<% end -%>
  it "should use <%= class_name %>Controller" do
    controller.should be_an_instance_of(<%= class_name %>Controller)
  end

<% unless actions.empty? -%>
<% for action in actions -%>

  it "GET '<%= action %>' should be successful" do
    get '<%= action %>'
    response.should be_success
  end
<% end -%>
<% end -%>
end
