require 'spec_helper'

# We'll use the OrderMailer as a quick and easy way to test.
# If it works here - it works for all email (in theory)
module Spree
  describe OrderMailer do
    let(:mail_method) { double('MailMethod') }
    let(:order) { Order.new(:email => "customer@example.com") }
    let(:message) { OrderMailer.confirm_email(order) }

    before { MailMethod.stub(:current => mail_method) }

    context "mail method preferences set" do
      before do
        mail_method.stub :preferred_mails_from => "no-reply@foobar.com"
        mail_method.stub :preferred_mail_bcc => "bcc-foo@foobar.com"
        mail_method.stub :preferred_intercept_email => "intercept@foobar.com"
      end

      it { message.deliver.from.should == ["no-reply@foobar.com"] }
      it { message.deliver.bcc.should == ["bcc-foo@foobar.com"] }
      it { message.deliver.to.should == ["intercept@foobar.com"] }

      it "modifies the subject to include the original email" do
        message.deliver.subject.should include(order.email)
      end

      context "except intercept mail" do
        before { mail_method.stub :preferred_intercept_email => "" }

        it "does not modify the recipient" do
          message.deliver.to.should == ["customer@example.com"]
        end
      end

      context "override actionmailer config set false" do
        before { Config.override_actionmailer_config = false }

        it "does not run spree interceptor" do
          message.deliver.to.should == ["customer@example.com"]
        end
      end
    end
  end
end
