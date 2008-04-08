require File.dirname(__FILE__) + '<%= '/..' * class_nesting_depth %>/../../spec_helper'

describe "/<%= table_name %>/index.<%= default_file_extension %>" do
  include <%= controller_class_name %>Helper
  
  before(:each) do
<% [98,99].each do |id| -%>
    <%= file_name %>_<%= id %> = mock_model(<%= class_name %>)
<% for attribute in attributes -%>
    <%= file_name %>_<%= id %>.should_receive(:<%= attribute.name %>).and_return(<%= attribute.default_value %>)
<% end -%><% end %>
    assigns[:<%= table_name %>] = [<%= file_name %>_98, <%= file_name %>_99]
  end

  it "should render list of <%= table_name %>" do
    render "/<%= table_name %>/index.<%= default_file_extension %>"
<% for attribute in attributes -%><% unless attribute.name =~ /_id/ || [:datetime, :timestamp, :time, :date].index(attribute.type) -%>
    response.should have_tag("tr>td", <%= attribute.default_value %>, 2)
<% end -%><% end -%>
  end
end

