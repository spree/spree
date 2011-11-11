require 'spec_helper'

describe Spree::Admin::MailMethodsController do
  let(:order) { mock_model(Spree::Order, :complete? => true).as_null_object }
  let(:mail_method) { mock_model(Spree::MailMethod).as_null_object }

  before do
    #controller.stub :current_user => nil
    Spree::Order.stub :find => order
    Spree::MailMethod.stub :find => mail_method
  end

  context "#create" do
    it "should reinitialize the mail settings" do
      Spree::Core::MailSettings.should_receive :init
      put :create, {:order_id => "123", :id => "456", :mail_method_parmas => {:environment => "foo"}}
    end
  end

  context "#update" do
    it "should reinitialize the mail settings" do
      Spree::Core::MailSettings.should_receive :init
      put :update, {:order_id => "123", :id => "456", :mail_method_parmas => {:environment => "foo"}}
    end
  end
end
