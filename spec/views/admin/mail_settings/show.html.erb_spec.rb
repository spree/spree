require File.expand_path(File.dirname(__FILE__) + '/../../../spec_helper')

describe "/admin/configurations/:id/mail_settings" do
  before(:each) do
    render 'admin/mail_settings/show'
  end
  
  #Delete this example and add some real ones or delete this file
  it "should have a div for mails settings" do
    response.should have_tag('div#mail_settings')
  end
end
