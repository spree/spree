require 'spec_helper'

module Spree
  module Core
    describe MailMethod do
      let(:mail_method){ described_class.new }
      let(:mail) do
        Mail.new do
          from 'spree@example.com'
          to 'customer@example.com'
        end
      end
      context "mail delivery enabled" do
        before { Config.enable_mail_delivery = true }
        it "should deliver mail" do
          expect {
            mail_method.deliver!(mail)
          }.to change { ActionMailer::Base.deliveries.size }.by(1)
        end
      end
      context "mail delivery disabled" do
        before { Config.enable_mail_delivery = false }
        it "shouldn't deliver mail" do
          expect {
            mail_method.deliver!(mail)
          }.not_to change { ActionMailer::Base.deliveries.size }
        end
      end
      describe "mailer uses custom settings" do
        subject { mail_method.mailer.settings }
        it { should == MailSettings.new.mail_server_settings }
      end
    end
  end
end
