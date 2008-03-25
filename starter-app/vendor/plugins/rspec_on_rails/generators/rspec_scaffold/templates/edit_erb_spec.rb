require File.dirname(__FILE__) + '<%= '/..' * class_nesting_depth %>/../../spec_helper'

describe "/<%= table_name %>/edit.<%= default_file_extension %>" do
  include <%= controller_class_name %>Helper
  
  before do
    @<%= file_name %> = mock_model(<%= class_name %>)
<% for attribute in attributes -%>
    @<%= file_name %>.stub!(:<%= attribute.name %>).and_return(<%= attribute.default_value %>)
<% end -%>
    assigns[:<%= file_name %>] = @<%= file_name %>
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


