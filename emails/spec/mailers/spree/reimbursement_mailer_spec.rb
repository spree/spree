require 'spec_helper'
require 'email_spec'

describe Spree::ReimbursementMailer, type: :mailer do
  include EmailSpec::Helpers
  include EmailSpec::Matchers

  let(:reimbursement) { create(:reimbursement) }

  context ':from not set explicitly' do
    it 'uses store mail from address' do
      message = Spree::ReimbursementMailer.reimbursement_email(reimbursement)
      expect(message.from).to eq [@default_store.mail_from_address]
    end
  end

  context ':reply_to not set explicitly' do
    it 'uses store mail from address' do
      message = Spree::ReimbursementMailer.reimbursement_email(reimbursement)
      expect(message.reply_to).to eq [@default_store.mail_from_address]
    end
  end

  it 'accepts a reimbursement id as an alternative to a Reimbursement object' do
    expect(Spree::Reimbursement).to receive(:find).with(reimbursement.id).and_return(reimbursement)

    expect do
      Spree::ReimbursementMailer.reimbursement_email(reimbursement.id).body
    end.not_to raise_error
  end

  context 'when order has no customer\'s name' do
    before { allow(reimbursement.order).to receive(:name).and_return(nil) }

    specify 'shows Dear Customer in email body' do
      reimbursement_email = described_class.reimbursement_email(reimbursement)
      expect(reimbursement_email).to have_body_text('Dear Customer')
    end
  end

  context 'when order has customer\'s name' do
    before { allow(reimbursement.order).to receive(:name).and_return('Test User') }

    specify 'shows order\'s user name in email body' do
      reimbursement_email = described_class.reimbursement_email(reimbursement)
      expect(reimbursement_email).to have_body_text('Dear Test User')
    end
  end

  context 'emails must be translatable' do
    context 'reimbursement_email' do
      context 'pt-BR locale' do
        before do
          reimbursement
          I18n.enforce_available_locales = false
          pt_br_shipped_email = { spree: { reimbursement_mailer: { reimbursement_email: { dear_customer: 'Caro Cliente,' } } } }
          I18n.backend.store_translations :'pt-BR', pt_br_shipped_email
          allow_any_instance_of(Spree::Store).to receive(:default_locale).and_return('pt-BR')
        end

        after do
          I18n.enforce_available_locales = true
        end

        it 'localized in HTML template' do
          reimbursement_email = Spree::ReimbursementMailer.reimbursement_email(reimbursement)
          reimbursement_email.html_part.to include('Caro Cliente,')
        end

        it 'localized in text template' do
          reimbursement_email = Spree::ReimbursementMailer.reimbursement_email(reimbursement)
          reimbursement_email.text_part.to include('Caro Cliente,')
        end
      end
    end
  end
end
