require 'spec_helper'

describe Spree::Core::MailSettings do
  context "init" do
    before { ActionMailer::Base.smtp_settings = {} }

    context "perform_delivery preference" do
      it "should override the application defaults" do
        Spree::Config[:enable_mail_delivery] = false
        Spree::Core::MailSettings.init
        ActionMailer::Base.perform_deliveries.should be_false
        Spree::Config[:enable_mail_delivery] = false # why set true here?
      end
    end

    context "when delivery is true" do
      before { Spree::Config[:enable_mail_delivery] = true }

      context "when mail_auth_type is other than none" do
        before { Spree::Config[:mail_auth_type] = "login" }

        context "mail_auth_type preference" do
          it "should override the application defaults" do
            Spree::Core::MailSettings.init
            ActionMailer::Base.smtp_settings[:authentication].should == "login"
          end
        end

        context "mail_host preference" do
          it "should override the application defaults" do
            Spree::Config[:mail_host] = "smtp.example.com"
            Spree::Core::MailSettings.init
            ActionMailer::Base.smtp_settings[:address].should == "smtp.example.com"
          end
        end

        context "mail_domain preference" do
          it "should override the application defaults" do
            Spree::Config[:mail_domain] = "example.com"
            Spree::Core::MailSettings.init
            ActionMailer::Base.smtp_settings[:domain].should == "example.com"
          end
        end

        context "mail_port preference" do
          it "should override the application defaults" do
            Spree::Config[:mail_port] = 123
            Spree::Core::MailSettings.init
            ActionMailer::Base.smtp_settings[:port].should == 123
          end
        end

        context "smtp_username preference" do
          it "should override the application defaults" do
            Spree::Config[:smtp_username] = "schof"
            Spree::Core::MailSettings.init
            ActionMailer::Base.smtp_settings[:user_name].should == "schof"
          end
        end

        context "smtp_password preference" do
          it "should override the application defaults" do
            Spree::Config[:smtp_password] = "hellospree!"
            Spree::Core::MailSettings.init
            ActionMailer::Base.smtp_settings[:password].should == "hellospree!"
          end
        end

        context "secure_connection_type preference" do
          it "should override the application defaults" do
            Spree::Config[:secure_connection_type] = "TLS"
            Spree::Core::MailSettings.init
            ActionMailer::Base.smtp_settings[:enable_starttls_auto].should be_true
          end
        end
      end
    end
  end
end
