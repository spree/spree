require 'spec_helper'

describe Spree::NewsletterMailer, type: :mailer do
  let(:store) { @default_store }
  let(:subscriber) { create(:newsletter_subscriber, :unverified, email: 'guest@example.com', store: store) }

  describe '#email_confirmation' do
    context 'when a redirect_url is provided' do
      it 'builds the confirmation link from the redirect URL with the verification token appended' do
        message = described_class.email_confirmation(subscriber, redirect_url: 'https://storefront.example.com/newsletter/confirm')

        expect(message.body.encoded).to include("https://storefront.example.com/newsletter/confirm?token=#{subscriber.verification_token}")
      end

      it 'merges the token into an existing query string instead of appending a new one' do
        message = described_class.email_confirmation(subscriber, redirect_url: 'https://storefront.example.com/newsletter/confirm?source=footer')

        expect(message.body.encoded).to include("https://storefront.example.com/newsletter/confirm?source=footer&amp;token=#{subscriber.verification_token}")
      end

      it 'preserves a URL fragment when appending the token' do
        message = described_class.email_confirmation(
          subscriber,
          redirect_url: 'https://storefront.example.com/account#newsletter'
        )

        # The token belongs in the query string, not after the fragment.
        expect(message.body.encoded).to include(
          "https://storefront.example.com/account?token=#{subscriber.verification_token}#newsletter"
        )
      end
    end

    context 'when no redirect_url is provided' do
      it 'falls back to the store storefront URL' do
        message = described_class.email_confirmation(subscriber)

        expect(message.body.encoded).to include(store.storefront_url.to_s)
        expect(message.body.encoded).to include("token=#{subscriber.verification_token}")
      end
    end

    it 'sends the email to the subscriber' do
      message = described_class.email_confirmation(subscriber)

      expect(message.to).to eq([subscriber.email])
    end
  end
end
