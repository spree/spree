require 'spec_helper'

# We'll use the OrderMailer as a quick and easy way to test. IF it works here
# it works for all email (in theory.)
describe Spree::OrderMailer do
  let(:order) { Spree::Order.new(:email => "customer@example.com") }
  let(:message) { Spree::OrderMailer.confirm_email(order) }

  before(:all) do
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries.clear
  end

  context "#deliver" do
    before do
      ActionMailer::Base.delivery_method = :test
    end

    after { ActionMailer::Base.deliveries.clear }

    it "should use the from address specified in the preference" do
      Spree::Config[:mails_from] = "no-reply@foobar.com"
      message.deliver
      @email = ActionMailer::Base.deliveries.first
      @email.from.should == ["no-reply@foobar.com"]
    end

    it "should use the provided from address" do
      Spree::Config[:mails_from] = "preference@foobar.com"
      message.from = "override@foobar.com"
      message.to = "test@test.com"
      message.deliver
      email = ActionMailer::Base.deliveries.first
      email.from.should == ["override@foobar.com"]
      email.to.should == ["test@test.com"]
    end

    it "should add the bcc email when provided" do
      Spree::Config[:mail_bcc] = "bcc-foo@foobar.com"
      message.deliver
      @email = ActionMailer::Base.deliveries.first
      @email.bcc.should == ["bcc-foo@foobar.com"]
    end

    context "when intercept_email is provided" do
      it "should strip the bcc recipients" do
        message.bcc.should be_blank
      end

      it "should strip the cc recipients" do
        message.cc.should be_blank
      end

      it "should replace the receipient with the specified address" do
        Spree::Config[:intercept_email] = "intercept@foobar.com"
        message.deliver
        @email = ActionMailer::Base.deliveries.first
        @email.to.should == ["intercept@foobar.com"]
      end

      it "should modify the subject to include the original email" do
        Spree::Config[:intercept_email] = "intercept@foobar.com"
        message.deliver
        @email = ActionMailer::Base.deliveries.first
        @email.subject.match(/customer@example\.com/).should be_true
      end
    end

    context "when intercept_mode is not provided" do
      it "should not modify the recipient" do
        Spree::Config[:intercept_email] = ""
        message.deliver
        @email = ActionMailer::Base.deliveries.first
        @email.to.should == ["customer@example.com"]
      end
    end
  end
end
