require 'spec_helper'

describe Spree::AdminUserMailer, type: :mailer do
  let(:store) { @default_store }
  let(:admin_user) { create(:admin_user, email: 'admin@example.com') }
  let(:token) { 'secret-reset-token' }

  describe '#password_reset_email' do
    it 'sends to the admin with the store-prefixed subject' do
      message = described_class.password_reset_email(admin_user, token, store)

      expect(message.to).to eq(['admin@example.com'])
      expect(message.subject).to eq("#{store.name} #{Spree.t('admin_user_mailer.password_reset_email.subject')}")
    end

    it 'links with the reset token' do
      message = described_class.password_reset_email(admin_user, token, store)

      expect(message.body.encoded).to include("token=#{token}")
    end

    it 'prefers the redirect URL when the API validated one (dashboard SPA)' do
      message = described_class.password_reset_email(admin_user, token, store, redirect_url: 'https://admin.example.com/reset-password')

      expect(message.body.encoded).to include("https://admin.example.com/reset-password?token=#{token}")
    end
  end

  describe '#confirmation_email' do
    it 'sends the confirmation with the store-prefixed subject and token link' do
      message = described_class.confirmation_email(admin_user, token, store)

      expect(message.to).to eq(['admin@example.com'])
      expect(message.subject).to eq("#{store.name} #{Spree.t('admin_user_mailer.confirmation_email.subject')}")
      expect(message.body.encoded).to include("token=#{token}")
    end
  end
end
