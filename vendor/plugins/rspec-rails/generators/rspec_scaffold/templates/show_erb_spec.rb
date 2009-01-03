require File.expand_path(File.dirname(__FILE__) + '<%= '/..' * class_nesting_depth %>/../../spec_helper')

<% output_attributes = attributes.reject{|attribute| [:datetime, :timestamp, :time, :date].index(attribute.type) } -%>
describe "/<%= table_name %>/show.<%= default_file_extension %>" do
  include <%= controller_class_name %>Helper
  before(:each) do
    assigns[:<%= file_name %>] = @<%= file_name %> = stub_model(<%= class_name %><%= output_attributes.empty? ? ')' : ',' %>
<% output_attributes.each_with_index do |attribute, attribute_index| -%>
      :<%= attribute.name %> => <%= attribute.default_value %><%= attribute_index == output_attributes.length - 1 ? '' : ','%>
<% end -%>
<% if !output_attributes.empty? -%>
    )
<% end -%>
  end

  it "should render attributes in <p>" do
    render "/<%= table_name %>/show.<%= default_file_extension %>"
<% for attribute in output_attributes -%>
    response.should have_text(/<%= Regexp.escape(attribute.default_value).gsub(/^"|"$/, '')%>/)
<% end -%>
  end
end

