require 'spec_helper'

RSpec.describe Spree::NewsletterMailer, type: :mailer do
  let(:store) { create(:store) }
  let(:subscriber) { create(:newsletter_subscriber, store: store, email: 'subscriber@example.com') }

  describe '#email_confirmation' do
    subject(:mail) { described_class.email_confirmation(subscriber) }

    it 'sends to the subscriber email' do
      expect(mail.to).to eq([subscriber.email])
    end

    it 'uses the store mail from address' do
      expect(mail.from).to eq([store.mail_from_address])
    end

    it 'renders the storefront verification URL in the body' do
      expected_url = "#{store.storefront_url}/newsletter/verify?token=#{subscriber.verification_token}"

      expect(mail.body.encoded).to include(expected_url)
    end
  end
end
