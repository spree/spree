require 'spec_helper'

describe Spree::Admin::MailMethodsController do
  stub_authorization!

  context "#update" do
    it "should reinitialize the mail settings" do
      Spree::Core::MailSettings.should_receive(:init)
      spree_put :update, { :enable_mail_delivery => "1", :mails_from => "spree@example.com" }
    end
  end

  it "can trigger testmail without current_user" do
    request.env["HTTP_REFERER"] = "/"
    controller.stub :try_spree_current_user => nil

    spree_post :testmail
    flash[:error].should_not include("undefined local variable or method `current_user'")
  end
end
