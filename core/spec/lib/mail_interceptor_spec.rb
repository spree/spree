require 'spec_helper'

# We'll use the OrderMailer as a quick and easy way to test.  IF it works here - it works for all email (in theory.)
describe Spree::OrderMailer do
  let(:mail_method) { mock("mail_method", :preferred_mails_from => nil, :preferred_intercept_email => nil, :preferred_mail_bcc => nil) }
  let(:order) { Spree::Order.new(:email => "customer@example.com") }
  let(:message) { Spree::OrderMailer.confirm_email(order) }
  #let(:email) { mock "email" }

  before do
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries.clear
  end

  context "#deliver" do
    before do
      ActionMailer::Base.delivery_method = :test
      Spree::MailMethod.stub :current => mail_method
    end

    it "should use the from address specified in the preference" do
      mail_method.stub :preferred_mails_from => "no-reply@foobar.com"
      message.deliver
      @email = ActionMailer::Base.deliveries.first
      @email.from.should == ["no-reply@foobar.com"]
    end

    it "should use the provided from address" do
      mail_method.stub :preferred_mails_from => "preference@foobar.com"
      message = ActionMailer::Base.mail(:from => "override@foobar.com", :to => "test@test.com")
      message.deliver
      @email = ActionMailer::Base.deliveries.first
      @email.from.should == ["override@foobar.com"]
    end

    it "should add the bcc email when provided" do
      mail_method.stub :preferred_mail_bcc => "bcc-foo@foobar.com"
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
        mail_method.stub :preferred_intercept_email => "intercept@foobar.com"
        message.deliver
        @email = ActionMailer::Base.deliveries.first
        @email.to.should == ["intercept@foobar.com"]
      end
      it "should modify the subject to include the original email" do
        mail_method.stub :preferred_intercept_email => "intercept@foobar.com"
        message.deliver
        @email = ActionMailer::Base.deliveries.first
        @email.subject.match(/customer@example\.com/).should be_true
      end
    end

    context "when intercept_mode is not provided" do
      before { mail_method.stub :preferred_intercept_email => "" }

      it "should not modify the recipient" do
        message.deliver
        @email = ActionMailer::Base.deliveries.first
        @email.to.should == ["customer@example.com"]
      end
      it "should bcc the address specified in the preference"
      it "should not change the recipient"
    end
  end
end
