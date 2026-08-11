require 'spec_helper'

# Exercises the whole path a carrier update travels: HTTP in, tracker parsed,
# core workflow run, fulfillment updated. The pieces are unit-tested
# separately; this is here because the wiring between them is what breaks.
RSpec.describe 'EasyPost tracker webhooks', type: :request do
  let(:store) { @default_store }
  let(:order) { create(:order_ready_to_ship, store: store) }
  let(:fulfillment) { order.fulfillments.first }

  def post_tracker(status:, tracking_code:, **result)
    post '/spree_easypost/webhooks', params: {
      description: 'tracker.updated',
      result: { object: 'Tracker', tracking_code: tracking_code, status: status, carrier: 'USPS' }.merge(result)
    }, as: :json
  end

  before do
    Spree.fulfillment_fulfill_workflow.call(fulfillment: fulfillment)
    fulfillment.reload.update!(tracking: 'EZ1000000001')
  end

  it 'records the carrier update on the fulfillment' do
    post_tracker(status: 'out_for_delivery', tracking_code: 'EZ1000000001')

    expect(response).to have_http_status(:ok)
    expect(fulfillment.reload.tracking_status).to eq('out_for_delivery')
  end

  it 'confirms receipt when the carrier reports delivery' do
    post_tracker(
      status: 'delivered',
      tracking_code: 'EZ1000000001',
      tracking_details: [{ status: 'delivered', datetime: '2026-08-13T14:20:00Z' }]
    )

    expect(fulfillment.reload).to be_delivered
    expect(fulfillment.delivered_at).to eq(Time.utc(2026, 8, 13, 14, 20))
  end

  # The whole point of the second axis: a bounced parcel is still a parcel the
  # merchant handed over.
  it 'records a bounce without moving the fulfillment backwards' do
    post_tracker(status: 'return_to_sender', tracking_code: 'EZ1000000001')

    expect(fulfillment.reload.tracking_status).to eq('return_to_sender')
    expect(fulfillment).to be_fulfilled
  end

  describe 'payloads it cannot act on' do
    it 'accepts an unknown tracking code without changing anything' do
      expect {
        post_tracker(status: 'delivered', tracking_code: 'EZ_NOT_OURS')
      }.not_to change { fulfillment.reload.status }

      expect(response).to have_http_status(:ok)
    end

    it 'accepts a webhook that is not a tracker update' do
      post '/spree_easypost/webhooks', params: { description: 'batch.created', result: {} }, as: :json

      expect(response).to have_http_status(:ok)
    end

    # Answering anything else would make EasyPost retry a payload that will
    # never succeed.
    it 'still answers 200 when the update itself fails' do
      allow(Spree.fulfillment_update_tracking_workflow).to receive(:call).and_raise('boom')

      post_tracker(status: 'in_transit', tracking_code: 'EZ1000000001')

      expect(response).to have_http_status(:ok)
    end
  end
end
