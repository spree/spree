require 'spec_helper'

describe Spree::Core::MailSettings do
  let(:mail_method) { Spree::MailMethod.new(:environment => "test") }
  let!(:subject) { Spree::Core::MailSettings.new }

  before { Spree::MailMethod.stub :current => mail_method }

  context "override option is true" do
    before { Spree::Config.override_actionmailer_config = true }

    context "init" do
      it "calls override!" do
        Spree::Core::MailSettings.should_receive(:new).and_return(subject)
        subject.should_receive(:override!)
        Spree::Core::MailSettings.init
      end
    end

    context "enable delivery" do
      before { mail_method.set_preference(:enable_mail_delivery, true) }

      context "overrides appplication defaults" do

        context "authentication method is none" do
          before do
            mail_method.set_preference(:mail_host, "smtp.example.com")
            mail_method.set_preference(:mail_domain, "example.com")
            mail_method.set_preference(:mail_port, 123)
            mail_method.set_preference(:mail_auth_type, "none")
            mail_method.set_preference(:smtp_username, "schof")
            mail_method.set_preference(:smtp_password, "hellospree!")
            mail_method.set_preference(:secure_connection_type, "TLS")
            subject.override!
          end

          it { ActionMailer::Base.smtp_settings[:address].should == "smtp.example.com" }
          it { ActionMailer::Base.smtp_settings[:domain].should == "example.com" }
          it { ActionMailer::Base.smtp_settings[:port].should == 123 }
          it { ActionMailer::Base.smtp_settings[:authentication].should == "none" }
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
          mail_method.set_preference(:mail_auth_type, "login")
          mail_method.set_preference(:smtp_username, "schof")
          mail_method.set_preference(:smtp_password, "hellospree!")
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
        mail_method.set_preference(:enable_mail_delivery, false)
        subject.override!
      end

      it { ActionMailer::Base.perform_deliveries.should be_false }
    end
  end

  context "override option is false" do
    before { Spree::Config.override_actionmailer_config = false }

    context "init" do
      it "doesnt calls override!" do
        Spree::Core::MailSettings.should_receive(:new).and_return(subject)
        subject.should_not_receive(:override!)
        Spree::Core::MailSettings.init
      end
    end
  end
end
