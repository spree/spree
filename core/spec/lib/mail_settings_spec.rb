require 'spec_helper'

module Spree
  module Core
    describe MailSettings do
      let!(:subject) { MailSettings.new }

      context "override option is true" do
        before { Config.override_actionmailer_config = true }

        context "init" do
          it "calls override!" do
            MailSettings.should_receive(:new).and_return(subject)
            subject.should_receive(:override!)
            MailSettings.init
          end
        end

        context "enable delivery" do
          before { Config.enable_mail_delivery = true }

          context "overrides appplication defaults" do

            context "authentication method is none" do
              before do
                Config.mail_host = "smtp.example.com"
                Config.mail_domain = "example.com"
                Config.mail_port = 123
                Config.mail_auth_type = MailSettings::SECURE_CONNECTION_TYPES[0]
                Config.smtp_username = "schof"
                Config.smtp_password = "hellospree!"
                Config.secure_connection_type = "TLS"
                subject.override!
              end

              it { ActionMailer::Base.smtp_settings[:address].should == "smtp.example.com" }
              it { ActionMailer::Base.smtp_settings[:domain].should == "example.com" }
              it { ActionMailer::Base.smtp_settings[:port].should == 123 }
              it { ActionMailer::Base.smtp_settings[:authentication].should == "None" }
              it { ActionMailer::Base.smtp_settings[:enable_starttls_auto].should be_true }

              it "doesnt touch user name config" do
                ActionMailer::Base.smtp_settings[:user_name].should == nil
              end

              it "doesnt touch password config" do
                ActionMailer::Base.smtp_settings[:password].should == nil
              end
            end
          end

          context "when mail_auth_type is other than none" do
            before do
              Config.mail_auth_type = "login"
              Config.smtp_username = "schof"
              Config.smtp_password = "hellospree!"
              subject.override!
            end

            context "overrides user credentials" do
              it { ActionMailer::Base.smtp_settings[:user_name].should == "schof" }
              it { ActionMailer::Base.smtp_settings[:password].should == "hellospree!" }
            end
          end
        end

        context "do not enable delivery" do
          before do
            Config.enable_mail_delivery = false
            subject.override!
          end

          it { ActionMailer::Base.perform_deliveries.should be_false }
        end
      end

      context "override option is false" do
        before { Config.override_actionmailer_config = false }

        context "init" do
          it "doesnt calls override!" do
            subject.should_not_receive(:override!)
            MailSettings.init
          end
        end
      end
    end
  end
end
