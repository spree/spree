require 'spec_helper'

describe Spree::Admin::MailMethodsController do
  stub_authorization!

  context "#update" do
    it "should reinitialize the mail settings" do
      spree_put :update, { :enable_mail_delivery => "1", :mails_from => "spree@example.com" }
      response.should be_redirect
    end
  end

  it "can trigger testmail" do
    user = create(:user, email: 'user@spree.com')
    controller.stub(:try_spree_current_user => user)
    Spree::Config[:enable_mail_delivery] = "1"

    expect {
      spree_post :testmail
    }.to change { ActionMailer::Base.deliveries.size }.by(1)
  end
end
