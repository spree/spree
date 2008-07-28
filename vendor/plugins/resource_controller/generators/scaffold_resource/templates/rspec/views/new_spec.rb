require File.expand_path(File.dirname(__FILE__) + '<%= '/..' * controller_class_nesting_depth %>/../../spec_helper')

describe "/<%= table_name %>/new.<%= default_file_extension %>" do
  include <%= controller_class_name %>Helper
  
  before(:each) do
    @<%= file_name %> = mock_model(<%= class_name %>)
    @<%= file_name %>.stub!(:new_record?).and_return(true)
<% for attribute in attributes -%>
    @<%= file_name %>.stub!(:<%= attribute.name %>).and_return(<%= attribute.default_value %>)
<% end -%>
    assigns[:<%= file_name %>] = @<%= file_name %>


    template.stub!(:object_url).and_return(<%= file_name %>_path(@<%= file_name %>)) 
    template.stub!(:collection_url).and_return(<%= file_name.pluralize %>_path) 
  end

  it "should render new form" do
    render "/<%= table_name %>/new.<%= default_file_extension %>"
    
    response.should have_tag("form[action=?][method=post]", <%= table_name %>_path) do
<% for attribute in attributes -%><% unless attribute.name =~ /_id/ || [:datetime, :timestamp, :time, :date].index(attribute.type) -%>
      with_tag("<%= attribute.input_type -%>#<%= file_name %>_<%= attribute.name %>[name=?]", "<%= file_name %>[<%= attribute.name %>]")
<% end -%><% end -%>
    end
  end
end


