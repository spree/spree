require 'spec_helper'

describe Spree::SellerUserMailer, type: :mailer do
  let(:store) { @default_store }
  let(:seller_user) { create(:admin_user, email: 'seller@example.com') }
  let(:token) { 'secret-reset-token' }

  describe '#password_reset_email' do
    it 'sends to the seller with the store-prefixed subject' do
      message = described_class.password_reset_email(seller_user, token, store)

      expect(message.to).to eq(['seller@example.com'])
      expect(message.subject).to eq("#{store.name} #{Spree.t('seller_user_mailer.password_reset_email.subject')}")
    end

    it 'links with the reset token' do
      message = described_class.password_reset_email(seller_user, token, store)

      expect(message.body.encoded).to include("token=#{token}")
    end

    it 'prefers the redirect URL when the API validated one' do
      message = described_class.password_reset_email(
        seller_user, token, store, redirect_url: 'https://sellers.example.com/reset-password'
      )

      expect(message.body.encoded).to include("https://sellers.example.com/reset-password?token=#{token}")
    end

    # The point of the separate mailer: without a redirect URL the link must
    # still open the seller panel. The storefront fallback the admin mailer
    # uses would land a seller on a page that cannot reset anything.
    it 'falls back to the seller panel origin, not the store URL' do
      allow(Spree::Sellers::PanelUrl).to receive(:call).with(store: store).and_return('https://sellers.example.com')

      message = described_class.password_reset_email(seller_user, token, store)

      expect(message.body.encoded).to include("https://sellers.example.com/reset-password?token=#{token}")
    end
  end
end
