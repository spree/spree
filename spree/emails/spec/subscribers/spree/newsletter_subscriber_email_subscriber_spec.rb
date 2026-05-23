# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::NewsletterSubscriberEmailSubscriber do
  let(:store) { create(:store) }
  let(:newsletter_subscriber) { create(:newsletter_subscriber, store: store) }
  let(:subscriber) { described_class.new }

  def mock_event(newsletter_subscriber, redirect_url: nil)
    payload = { 'id' => newsletter_subscriber.prefixed_id }
    payload['redirect_url'] = redirect_url if redirect_url
    double('Event', payload: payload)
  end

  before do
    store.update!(preferences: store.preferences.merge(send_consumer_transactional_emails: true))
  end

  describe 'newsletter_subscriber.subscription_requested event' do
    it 'sends email confirmation without a redirect URL when none is provided' do
      expect(Spree::NewsletterMailer).to receive(:email_confirmation).with(newsletter_subscriber, redirect_url: nil).and_return(double(deliver_later: true))

      subscriber.handle(mock_event(newsletter_subscriber))
    end

    it 'forwards the redirect URL from the event payload' do
      expect(Spree::NewsletterMailer).to receive(:email_confirmation).
        with(newsletter_subscriber, redirect_url: 'https://storefront.example.com/newsletter/confirm').
        and_return(double(deliver_later: true))

      subscriber.handle(mock_event(newsletter_subscriber, redirect_url: 'https://storefront.example.com/newsletter/confirm'))
    end

    context 'when subscriber is already verified' do
      let(:newsletter_subscriber) { create(:newsletter_subscriber, :verified) }

      it 'does not send email confirmation' do
        expect(Spree::NewsletterMailer).not_to receive(:email_confirmation)

        subscriber.handle(mock_event(newsletter_subscriber))
      end
    end

    context 'when store does not prefer transactional emails' do
      before do
        store.update!(preferences: store.preferences.merge(send_consumer_transactional_emails: false))
      end

      it 'does not send email confirmation' do
        expect(Spree::NewsletterMailer).not_to receive(:email_confirmation)

        subscriber.handle(mock_event(newsletter_subscriber))
      end
    end

    context 'when subscriber not found' do
      it 'does not raise an error' do
        newsletter_subscriber.destroy

        expect { subscriber.handle(mock_event(newsletter_subscriber)) }.not_to raise_error
      end
    end
  end
end
