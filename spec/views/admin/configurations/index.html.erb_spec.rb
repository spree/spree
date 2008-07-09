require File.expand_path(File.dirname(__FILE__) + '/../../../spec_helper')

describe "/admin/configurations" do
  before(:each) do
    render 'admin/configurations/index'
  end
  
  it "should have a link to create a new configuration template" do
    response.should have_tag('a[href=?]', '/admin/configurations/new')
  end
end
