require 'spec_helper'

RSpec.describe SpreeKlaviyo::FulfillmentSubscriber do
  let(:store) { @default_store }
  let(:fulfillment) { create(:completed_order_with_totals, store: store).fulfillments.first }

  def handle(metadata: {})
    described_class.new.call(spree_event('fulfillment.fulfilled', { id: fulfillment.prefixed_id }, metadata: metadata))
  end

  it 'sends Fulfilled Order with the notify choice' do
    integration = create(:klaviyo_integration, :active, store: store)

    expect { handle(metadata: { notify_customer: false }) }.
      to have_enqueued_job(SpreeKlaviyo::TrackEventJob).with(integration, fulfillment, 'fulfilled_order', notify_customer: false)
  end

  it 'enqueues nothing without an active Klaviyo integration' do
    create(:klaviyo_integration, store: store, active: false)

    expect { handle }.not_to enqueue_a_klaviyo_job
  end
end
