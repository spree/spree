require File.expand_path(File.dirname(__FILE__) + '<%= '/..' * class_nesting_depth %>/../../spec_helper')

<% output_attributes = attributes.reject{|attribute| [:datetime, :timestamp, :time, :date].index(attribute.type) } -%>
describe "/<%= table_name %>/new.<%= default_file_extension %>" do
  include <%= controller_class_name %>Helper
  
  before(:each) do
    assigns[:<%= file_name %>] = stub_model(<%= class_name %>,
      :new_record? => true<%= output_attributes.empty? ? '' : ',' %>
<% output_attributes.each_with_index do |attribute, attribute_index| -%>
      :<%= attribute.name %> => <%= attribute.default_value %><%= attribute_index == output_attributes.length - 1 ? '' : ','%>
<% end -%>
    )
  end

  it "should render new form" do
    render "/<%= table_name %>/new.<%= default_file_extension %>"
    
    response.should have_tag("form[action=?][method=post]", <%= table_name %>_path) do
<% for attribute in output_attributes -%>
      with_tag("<%= attribute.input_type -%>#<%= file_name %>_<%= attribute.name %>[name=?]", "<%= file_name %>[<%= attribute.name %>]")
<% end -%>
    end
  end
end


