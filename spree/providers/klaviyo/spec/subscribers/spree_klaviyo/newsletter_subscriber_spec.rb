require 'spec_helper'

RSpec.describe SpreeKlaviyo::NewsletterSubscriber do
  let(:store) { @default_store }
  let(:subscriber_row) { create(:newsletter_subscriber, store: store, email: 'ada@example.com') }

  def handle(name, payload)
    described_class.new.call(spree_event(name, payload))
  end

  context 'with an active Klaviyo integration' do
    let!(:integration) { create(:klaviyo_integration, :active, store: store) }

    %w[newsletter_subscriber.subscription_requested newsletter_subscriber.verified].each do |name|
      it "subscribes the address on #{name}" do
        expect { handle(name, id: subscriber_row.prefixed_id, email: subscriber_row.email) }.
          to have_enqueued_job(SpreeKlaviyo::UpdateSubscriptionJob).with(integration, 'ada@example.com', subscribed: true)
      end
    end

    it 'unsubscribes a deleted subscriber with the email from the event' do
      payload = { id: subscriber_row.prefixed_id, email: subscriber_row.email }
      subscriber_row.destroy!

      expect { handle('newsletter_subscriber.deleted', payload) }.
        to have_enqueued_job(SpreeKlaviyo::UpdateSubscriptionJob).with(integration, 'ada@example.com', subscribed: false)
    end
  end

  it 'enqueues nothing without an active Klaviyo integration' do
    create(:klaviyo_integration, store: store, active: false)

    expect { handle('newsletter_subscriber.verified', id: subscriber_row.prefixed_id) }.not_to enqueue_a_klaviyo_job
    expect { handle('newsletter_subscriber.deleted', email: 'ada@example.com') }.not_to enqueue_a_klaviyo_job
  end
end
