require "spec_helper"

# We'll use the OrderMailer as a quick and easy way to test.  IF it works here - it works for all email (in theory.)
describe OrderMailer do
  let(:mail_method) { mock("mail_method", :preferred_mails_from => nil, :preferred_intercept_email => nil) }
  let(:order) { Order.new(:email => "customer@example.com") }
  let(:message) { OrderMailer.confirm_email(order) }
  #let(:email) { mock "email" }

  context "#deliver" do
    before do
      ActionMailer::Base.delivery_method = :test
      MailMethod.stub :current => mail_method
    end
    after { ActionMailer::Base.deliveries.clear }

    it "should use the from address specified in the preference" do
      mail_method.stub :preferred_mails_from => "no-reply@foobar.com"
      message.deliver
      @email = ActionMailer::Base.deliveries.first
      @email.from.should == ["no-reply@foobar.com"]
    end

    it "should add the bcc email when provided"

    context "when intercept_email is provided" do
      before {  }
      it "should strip the bcc recipients"
      it "should strip the cc recipients"
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
        @email.subject.starts_with?("[customer@example.com]").should be_true
      end
    end

    context "when intercept_mode is not provided" do
      it "should bcc the address specified in the preference"
      it "should not change the recipient"
    end
  end
end