require 'spec_helper'

describe Spree::Admin::MailMethodsController do
  stub_authorization!

  let(:order) { mock_model(Spree::Order, :complete? => true).as_null_object }
  let(:mail_method) { mock_model(Spree::MailMethod).as_null_object }

  before do
    Spree::Order.stub :find => order
    Spree::MailMethod.stub :find => mail_method
    request.env["HTTP_REFERER"] = "/"
  end

  context "#create" do
    it "should reinitialize the mail settings" do
      Spree::Core::MailSettings.should_receive :init
      spree_put :create, {:order_id => "123", :id => "456", :mail_method_parmas => {:environment => "foo"}}
    end
  end

  context "#update" do
    it "should reinitialize the mail settings" do
      Spree::Core::MailSettings.should_receive :init
      spree_put :update, {:order_id => "123", :id => "456", :mail_method_params => {:environment => "foo"}}
    end
  end

  it "can trigger testmail without current_user" do
    spree_post :testmail, :id => create(:mail_method).id
    flash[:error].should_not include("undefined local variable or method `current_user'")
  end
end
