require File.dirname(__FILE__) + '/../../spec_helper'

describe Admin::MailMethodsController do
  let(:order) { mock_model(Order, :complete? => true).as_null_object }
  let(:mail_method) { mock_model(MailMethod).as_null_object }

  before do
    #controller.stub :current_user => nil
    Order.stub :find => order
    MailMethod.stub :find => mail_method
  end

  context "#create" do
    it "should reinitialize the mail settings" do
      Spree::MailSettings.should_receive :init
      put :create, {:order_id => "123", :id => "456", :mail_method_parmas => {:environment => "foo"}}
    end
  end

  context "#update" do
    it "should reinitialize the mail settings" do
      Spree::MailSettings.should_receive :init
      put :update, {:order_id => "123", :id => "456", :mail_method_parmas => {:environment => "foo"}}
    end
  end
end
