require 'spec_helper'

RSpec.describe Spree::Deliveries::Destroy do
  subject(:service) { described_class.new }

  let(:store) { @default_store }
  let(:fulfillment) { create(:order_ready_to_ship, store: store).fulfillments.first }

  it 'removes a hand-entered delivery' do
    delivery = fulfillment.deliveries.first

    expect(service.call(delivery: delivery)).to be_success
    expect(Spree::Delivery.exists?(delivery.id)).to be(false)
  end

  it 'refuses a delivery minted by a label' do
    label = create(:shipping_label, :with_delivery, owner: fulfillment)

    result = service.call(delivery: label.delivery)

    expect(result).to be_failure
    expect(result.error.to_s).to eq(Spree.t('deliveries.errors.has_label'))
    expect(label.reload.delivery).to be_present
  end
  # Arrival is what the returns window and the withdrawal period count from,
  # so it is a fact to correct rather than erase.
  it 'refuses one that already arrived' do
    delivery = fulfillment.deliveries.first
    delivery.update_columns(status: 'delivered', delivered_at: Time.current)

    result = service.call(delivery: delivery)

    expect(result).to be_failure
    expect(result.error.to_s).to eq(Spree.t('deliveries.errors.delivered'))
    expect(Spree::Delivery.exists?(delivery.id)).to be(true)
  end
end
