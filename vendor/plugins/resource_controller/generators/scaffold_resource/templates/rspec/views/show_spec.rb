require File.expand_path(File.dirname(__FILE__) + '<%= '/..' * controller_class_nesting_depth %>/../../spec_helper')

describe "/<%= table_name %>/show.<%= default_file_extension %>" do
  include <%= controller_class_name %>Helper
  
  before(:each) do
    @<%= file_name %> = mock_model(<%= class_name %>)
<% for attribute in attributes -%>
    @<%= file_name %>.stub!(:<%= attribute.name %>).and_return(<%= attribute.default_value %>)
<% end -%>

    assigns[:<%= file_name %>] = @<%= file_name %>

    template.stub!(:edit_object_url).and_return(edit_<%= file_name %>_path(@<%= file_name %>)) 
    template.stub!(:collection_url).and_return(<%= file_name.pluralize %>_path) 
  end

  it "should render attributes in <p>" do
    render "/<%= table_name %>/show.<%= default_file_extension %>"
<% for attribute in attributes -%><% unless attribute.name =~ /_id/ || [:datetime, :timestamp, :time, :date].index(attribute.type) -%>
    response.should have_text(/<%= Regexp.escape(attribute.default_value)[1..-2]%>/)
<% end -%><% end -%>
  end
end

