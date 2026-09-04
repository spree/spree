require 'spec_helper'

RSpec.describe Spree::Fulfillments::RecalculateDelivery do
  subject(:service) { described_class.new }

  let(:store) { @default_store }
  let(:fulfillment) { create(:order_ready_to_ship, store: store).fulfillments.first }

  def deliver(delivery)
    Spree.delivery_update_tracking_workflow.call(delivery: delivery, tracking_status: 'delivered')
  end

  before { Spree.fulfillment_fulfill_workflow.call(fulfillment: fulfillment) }

  # One line item can travel as several parcels — a gym rack in three boxes —
  # so arrival is the answer to "have they all landed", not a flag.
  it 'waits for every parcel before the fulfillment is delivered' do
    second = Spree.delivery_create_service.call(owner: fulfillment, tracking_number: 'BOX-2').value

    deliver(fulfillment.deliveries.first)
    expect(fulfillment.reload).to be_fulfilled

    deliver(second)
    expect(fulfillment.reload).to be_delivered
  end

  it 'stamps the fulfillment with the last parcel to arrive' do
    second = Spree.delivery_create_service.call(owner: fulfillment, tracking_number: 'BOX-2').value
    fulfillment.deliveries.first.update_columns(status: 'delivered', delivered_at: 3.days.ago)
    second.update_columns(status: 'delivered', delivered_at: 1.hour.ago)

    service.call(fulfillment: fulfillment)

    expect(fulfillment.reload.delivered_at).to be_within(1.second).of(1.hour.ago)
  end

  # The bug this service exists for: a parcel added after the fulfillment was
  # marked delivered used to leave it claiming an arrival that had not happened.
  it 'steps back when a parcel joins a delivered fulfillment' do
    deliver(fulfillment.deliveries.first)
    expect(fulfillment.reload).to be_delivered

    Spree.delivery_create_service.call(owner: fulfillment, tracking_number: 'LATE-BOX')

    expect(fulfillment.reload).to be_fulfilled
    # The stamp goes with it: the returns window counts from arrival, and the
    # fulfillment has not arrived.
    expect(fulfillment.delivered_at).to be_nil
  end

  it 'completes when the last parcel still travelling is removed' do
    late = Spree.delivery_create_service.call(owner: fulfillment, tracking_number: 'LATE-BOX').value
    deliver(fulfillment.deliveries.first)
    expect(fulfillment.reload).to be_fulfilled

    Spree.delivery_destroy_service.call(delivery: late)

    expect(fulfillment.reload).to be_delivered
  end

  # Pickup, hand delivery and freight with no carrier feed are delivered by
  # staff saying so; there is nothing here to compute from.
  it 'leaves a fulfillment with no parcels alone' do
    fulfillment.deliveries.destroy_all
    Spree.fulfillment_mark_delivered_workflow.call(fulfillment: fulfillment)

    expect(service.call(fulfillment: fulfillment.reload)).to be_success
    expect(fulfillment.reload).to be_delivered
  end

  it 'does nothing to a parcel that never shipped' do
    unfulfilled = create(:order_ready_to_ship, store: store).fulfillments.first
    unfulfilled.deliveries.first.update_columns(status: 'delivered', delivered_at: Time.current)

    service.call(fulfillment: unfulfilled)

    expect(unfulfilled.reload).to be_unfulfilled
  end
end
