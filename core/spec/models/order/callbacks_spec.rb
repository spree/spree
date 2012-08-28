require 'spec_helper'

describe Spree::Order do
  let(:order) { stub_model(Spree::Order) }

  context "validations" do
    context "email validation" do
      # Regression test for #1238
      it "o'brien@gmail.com is a valid email address" do
        order.state = 'address'
        order.email = "o'brien@gmail.com"
        p order.valid?
        p order.errors
        order.should be_valid
      end
    end
  end

  context "#save" do
    context "when associated with a registered user" do
      let(:user) { stub(:user, :email => "test@example.com") }

      before do
        order.stub :user => user
      end

      it "should assign the email address of the user" do
        order.run_callbacks(:create)
        order.email.should == user.email
      end
    end
  end

  context "in the cart state" do
    it "should not validate email address" do
      order.state = "cart"
      order.email = nil
      order.should be_valid
    end
  end
end
