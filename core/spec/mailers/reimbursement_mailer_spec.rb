require 'spec_helper'
require 'email_spec'

describe Spree::ReimbursementMailer do
  include EmailSpec::Helpers
  include EmailSpec::Matchers

  let(:reimbursement) { create(:reimbursement) }

  context ":from not set explicitly" do
    it "falls back to spree config" do
      message = Spree::ReimbursementMailer.reimbursement_email(reimbursement)
      expect(message.from).to eq [Spree::Config[:mails_from]]
    end
  end

  it "accepts a reimbursement id as an alternative to a Reimbursement object" do
    Spree::Reimbursement.should_receive(:find).with(reimbursement.id).and_return(reimbursement)

    lambda {
      reimbursement_email = Spree::ReimbursementMailer.reimbursement_email(reimbursement.id)
    }.should_not raise_error
  end

  context "emails must be translatable" do
    context "reimbursement_email" do
      context "pt-BR locale" do
        before do
          I18n.enforce_available_locales = false
          pt_br_shipped_email = { :spree => { :reimbursement_mailer => { :reimbursement_email => { :dear_customer => 'Caro Cliente,' } } } }
          I18n.backend.store_translations :'pt-BR', pt_br_shipped_email
          I18n.locale = :'pt-BR'
        end

        after do
          I18n.locale = I18n.default_locale
          I18n.enforce_available_locales = true
        end

        specify do
          reimbursement_email = Spree::ReimbursementMailer.reimbursement_email(reimbursement)
          reimbursement_email.body.should include("Caro Cliente,")
        end
      end
    end
  end
end
