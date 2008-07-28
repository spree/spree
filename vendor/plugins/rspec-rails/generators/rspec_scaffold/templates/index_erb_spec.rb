require File.expand_path(File.dirname(__FILE__) + '<%= '/..' * class_nesting_depth %>/../../spec_helper')

describe "/<%= table_name %>/index.<%= default_file_extension %>" do
  include <%= controller_class_name %>Helper
  
  before(:each) do
    assigns[:<%= table_name %>] = [
<% [1,2].each_with_index do |id, model_index| -%>
      stub_model(<%= class_name %><%= attributes.empty? ? (model_index == 1 ? ')' : '),') : ',' %>
<% attributes.each_with_index do |attribute, attribute_index| -%><% unless attribute.name =~ /_id/ || [:datetime, :timestamp, :time, :date].index(attribute.type) -%>
        :<%= attribute.name %> => <%= attribute.default_value %><%= attribute_index == attributes.length - 1 ? '' : ','%>
<% end -%><% end -%>
<% if !attributes.empty? -%>
      <%= model_index == 1 ? ')' : '),' %>
<% end -%>
<% end -%>
    ]
  end

  it "should render list of <%= table_name %>" do
    render "/<%= table_name %>/index.<%= default_file_extension %>"
<% for attribute in attributes -%><% unless attribute.name =~ /_id/ || [:datetime, :timestamp, :time, :date].index(attribute.type) -%>
    response.should have_tag("tr>td", <%= attribute.default_value %>, 2)
<% end -%><% end -%>
  end
end

