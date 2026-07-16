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
end
