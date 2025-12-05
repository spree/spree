require 'spec_helper'

module Spree
  describe Newsletter::Verify do
    subject(:service) { described_class.new(**params).call }

    let(:params) do
      {
        subscriber: subscriber
      }
    end

    let(:subscriber) { create(:newsletter_subscriber, :unverified, user: user) }

    around do |example|
      Timecop.freeze('2137-01-01') { example.run }
    end

    context 'with associated user' do
      let(:user) { create(:user, accepts_email_marketing: false) }

      it 'verifies a subscription' do
        expect { service }.to change { subscriber.reload.verified_at }.from(nil).to('2137-01-01'.to_datetime).
          and change { subscriber.reload.verification_token }.to(nil)
      end

      it 'updates user email marketing attribute' do
        expect { service }.to change { subscriber.user.accepts_email_marketing }.to(true)
      end
    end

    context 'without user' do
      let(:user) { nil }

      it 'verifies a subscription' do
        expect { service }.to change { subscriber.reload.verified_at }.from(nil).to('2137-01-01'.to_datetime).
          and change { subscriber.reload.verification_token }.to(nil)
      end
    end

    describe 'custom events' do
      let(:user) { nil }

      it 'publishes newsletter_subscriber.verify event when verified' do
        Spree::Events.activate!

        received_event = nil
        event_subscriber = Spree::Events.subscribe('newsletter_subscriber.verify') do |event|
          received_event = event
        end

        service

        expect(received_event).to be_present
        expect(received_event.metadata['model_class']).to eq('Spree::NewsletterSubscriber')
        expect(received_event.metadata['model_id']).to eq(subscriber.id.to_s)

        Spree::Events.unsubscribe('newsletter_subscriber.verify', event_subscriber)
        Spree::Events.reset!
      end
    end
  end
end
