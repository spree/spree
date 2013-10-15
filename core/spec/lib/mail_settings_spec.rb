require 'spec_helper'

module Spree
  module Core
    describe MailSettings do
      context "override option is true" do
        before { Config.override_actionmailer_config = true }

        it "calls override!" do
          ActionMailer::Base.should_receive(:delivery_method=).with(:spree)
          MailSettings.init
        end
      end

      context "override option is false" do
        before { Config.override_actionmailer_config = false }

        it "doesnt calls override!" do
          MailSettings.should_not_receive(:override!)
          MailSettings.init
        end
      end

      describe "mail_server_settings" do
        subject{ described_class.new.mail_server_settings }
        context "authentication method is none" do
          before do
            Config.mail_host = "smtp.example.com"
            Config.mail_domain = "example.com"
            Config.mail_port = 123
            Config.mail_auth_type = MailSettings::SECURE_CONNECTION_TYPES[0]
            Config.smtp_username = "schof"
            Config.smtp_password = "hellospree!"
            Config.secure_connection_type = "TLS"
          end

          it { subject[:address].should == "smtp.example.com" }
          it { subject[:domain].should == "example.com" }
          it { subject[:port].should == 123 }
          it { subject[:authentication].should == "None" }
          it { subject[:enable_starttls_auto].should be_true }
          it { should_not have_key(:user_name) }
          it { should_not have_key(:password) }
        end

        context "when mail_auth_type is other than none" do
          before do
            Config.mail_auth_type = "login"
            Config.smtp_username = "schof"
            Config.smtp_password = "hellospree!"
          end

          context "overrides user credentials" do
            it { subject[:user_name].should == "schof" }
            it { subject[:password].should == "hellospree!" }
          end
        end
      end
    end
  end
end
