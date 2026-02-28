# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::NewsletterSubscriberEmailSubscriber do
  let(:store) { create(:store) }
  let(:newsletter_subscriber) { create(:newsletter_subscriber) }
  let(:subscriber) { described_class.new }

  def mock_event(newsletter_subscriber)
    double('Event', payload: { 'id' => newsletter_subscriber.id })
  end

  before do
    allow(Spree::Current).to receive(:store).and_return(store)
    store.update!(preferences: store.preferences.merge(send_consumer_transactional_emails: true))
  end

  describe 'newsletter_subscriber.subscribed event' do
    it 'sends email confirmation' do
      expect(Spree::NewsletterMailer).to receive(:email_confirmation).with(newsletter_subscriber).and_return(double(deliver_later: true))

      subscriber.handle(mock_event(newsletter_subscriber))
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
