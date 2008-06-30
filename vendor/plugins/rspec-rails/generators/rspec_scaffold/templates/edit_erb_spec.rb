require File.expand_path(File.dirname(__FILE__) + '<%= '/..' * class_nesting_depth %>/../../spec_helper')

describe "/<%= table_name %>/edit.<%= default_file_extension %>" do
  include <%= controller_class_name %>Helper
  
  before(:each) do
    assigns[:<%= file_name %>] = @<%= file_name %> = stub_model(<%= class_name %>,
      :new_record? => false<%= attributes.empty? ? '' : ',' %>
<% attributes.each_with_index do |attribute, attribute_index| -%><% unless attribute.name =~ /_id/ || [:datetime, :timestamp, :time, :date].index(attribute.type) -%>
      :<%= attribute.name %> => <%= attribute.default_value %><%= attribute_index == attributes.length - 1 ? '' : ','%>
<% end -%><% end -%>
    )
  end

  it "should render edit form" do
    render "/<%= table_name %>/edit.<%= default_file_extension %>"
    
    response.should have_tag("form[action=#{<%= file_name %>_path(@<%= file_name %>)}][method=post]") do
<% for attribute in attributes -%><% unless attribute.name =~ /_id/ || [:datetime, :timestamp, :time, :date].index(attribute.type) -%>
      with_tag('<%= attribute.input_type -%>#<%= file_name %>_<%= attribute.name %>[name=?]', "<%= file_name %>[<%= attribute.name %>]")
<% end -%><% end -%>
    end
  end
end


