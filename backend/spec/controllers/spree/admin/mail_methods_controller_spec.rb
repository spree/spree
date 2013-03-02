require 'spec_helper'

describe Spree::Admin::MailMethodsController do
  stub_authorization!

  context "#update" do
    it "should reinitialize the mail settings" do
      Spree::Core::MailSettings.should_receive(:init)
      spree_put :update, { :enable_mail_delivery => "1", :mails_from => "spree@example.com" }
    end
  end

  it "can trigger testmail" do
    request.env["HTTP_REFERER"] = "/"
    controller.stub(:try_spree_current_user => double('User', email: 'user@spree.com'))

    expect {
      spree_post :testmail
    }.to change { ActionMailer::Base.deliveries.size }.by(1)
  end
end
