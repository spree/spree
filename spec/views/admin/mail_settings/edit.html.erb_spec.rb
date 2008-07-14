require File.expand_path(File.dirname(__FILE__) + '/../../../spec_helper')

include PreferenceFactory

describe "/admin/configurations/:id/mail_settings/edit" do
  before(:each) do
    render 'admin/mail_settings/edit'
  end
  
  #Delete this example and add some real ones or delete this file
  it "should render the edit form" do
    response.should have_tag('form[action=?]', admin_mail_settings_path)
  end
end
