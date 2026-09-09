require 'spec_helper'
require 'email_spec'

describe Spree::CustomerMailer, type: :mailer do
  include EmailSpec::Helpers
  include EmailSpec::Matchers

  let(:store) { @default_store }
  let(:user) { create(:user, email: 'customer@example.com') }
  let(:reset_token) { 'secret-reset-token' }

  describe '#password_reset_email' do
    it 'sends to the user with the store-prefixed subject' do
      message = described_class.password_reset_email(user, reset_token, store)

      expect(message.to).to eq(['customer@example.com'])
      expect(message.from).to eq([store.mail_from_address])
      expect(message.subject).to eq("#{store.name} #{Spree.t('customer_mailer.password_reset_email.subject')}")
    end

    it 'links to the storefront URL with the reset token appended' do
      message = described_class.password_reset_email(user, reset_token, store)

      expect(message).to have_body_text("token=#{reset_token}")
      expect(message).to have_body_text(store.storefront_url.to_s)
    end

    it 'prefers the redirect URL when one was validated by the API' do
      message = described_class.password_reset_email(user, reset_token, store, redirect_url: 'https://storefront.example.com/account/reset-password')

      expect(message).to have_body_text("https://storefront.example.com/account/reset-password?token=#{reset_token}")
    end
  end

  describe '#data_export_email' do
    let(:data_request) { create(:data_request, store: store, customer: user) }

    before { Spree::DataRequests::Fulfill.call(data_request: data_request) }

    it 'sends to the person who asked for their data' do
      message = described_class.data_export_email(data_request.reload)

      expect(message.to).to eq(['customer@example.com'])
      expect(message.subject).to eq("#{store.name} #{Spree.t('customer_mailer.data_export_email.subject')}")
    end

    it 'carries a link to the file' do
      message = described_class.data_export_email(data_request.reload)

      expect(message).to have_body_text(Spree.t('customer_mailer.data_export_email.action'))
    end
  end
end
