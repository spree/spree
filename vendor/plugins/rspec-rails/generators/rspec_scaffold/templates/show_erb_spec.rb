require File.expand_path(File.dirname(__FILE__) + '<%= '/..' * class_nesting_depth %>/../../spec_helper')

describe "/<%= table_name %>/show.<%= default_file_extension %>" do
  include <%= controller_class_name %>Helper
  
  before(:each) do
    assigns[:<%= file_name %>] = @<%= file_name %> = stub_model(<%= class_name %><%= attributes.empty? ? ')' : ',' %>
<% attributes.each_with_index do |attribute, attribute_index| -%><% unless attribute.name =~ /_id/ || [:datetime, :timestamp, :time, :date].index(attribute.type) -%>
      :<%= attribute.name %> => <%= attribute.default_value %><%= attribute_index == attributes.length - 1 ? '' : ','%>
<% end -%><% end -%>
<% if !attributes.empty? -%>
    )
<% end -%>
  end

  it "should render attributes in <p>" do
    render "/<%= table_name %>/show.<%= default_file_extension %>"
<% for attribute in attributes -%><% unless attribute.name =~ /_id/ || [:datetime, :timestamp, :time, :date].index(attribute.type) -%>
    response.should have_text(/<%= Regexp.escape(attribute.default_value)[1..-2]%>/)
<% end -%><% end -%>
  end
end

