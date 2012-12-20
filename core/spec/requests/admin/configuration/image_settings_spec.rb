require 'spec_helper'

describe "image settings" do
  stub_authorization!

  before do
    visit spree.admin_path
    click_link "Configuration"
    click_link "Image Settings"
    click_link "Edit"
  end
  
  # Regression test for #2344
  it "can update attachment_url", :js => true do
    fill_in "Attachments URL", :with => "foobar"
    fill_in "Attachments Default URL", :with => "barfoo"
    fill_in "Attachments Path", :with => "bfaoro" 
    click_button "Update"

    Spree::Config[:attachment_url].should == "foobar"
    Spree::Config[:attachment_default_url].should == "barfoo"
    Spree::Config[:attachment_path].should == "bfaoro"
  end

end

