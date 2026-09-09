require 'spec_helper'

RSpec.describe Spree::Deliveries::UpsertPrimary do
  subject(:service) { described_class.new }

  let(:store) { @default_store }
  let(:fulfillment) { create(:order_ready_to_ship, store: store).fulfillments.first }

  it 'creates the primary consignment when there is none' do
    fulfillment.deliveries.destroy_all

    result = service.call(fulfillment: fulfillment, tracking: '1Z879E930346834440')

    expect(result).to be_success
    expect(fulfillment.reload.tracking).to eq('1Z879E930346834440')
    expect(fulfillment.primary_delivery.carrier).to eq('ups')
  end

  it 'is a no-op when nothing was asked' do
    expect { service.call(fulfillment: fulfillment, tracking: nil) }.
      not_to change { fulfillment.deliveries.count }
  end

  # A corrected number is a different parcel: everything that described the
  # old one goes with it, or a UPS badge and a UPS page survive onto a
  # number that belongs to another carrier.
  it 'drops the old carrier, link and carrier status when the number changes' do
    delivery = fulfillment.primary_delivery
    delivery.update!(tracking_number: '1Z879E930346834440', tracking_url: 'https://old.example/t/1')
    delivery.update_columns(status: 'in_transit')
    expect(delivery.carrier).to eq('ups')

    service.call(fulfillment: fulfillment, tracking: 'PRO-4471923')

    delivery.reload
    expect(delivery.tracking_number).to eq('PRO-4471923')
    expect(delivery.status).to eq('pending')
    expect(delivery.carrier).to be_nil
    expect(delivery.tracking_url).to be_nil
    expect(delivery.resolved_tracking_url).to be_nil
  end

  it 'keeps a carrier the caller supplied with the corrected number' do
    service.call(fulfillment: fulfillment, tracking: 'PRO-4471923', carrier: 'Estes Freight')

    expect(fulfillment.primary_delivery.reload.carrier).to eq('Estes Freight')
  end

  it 'leaves everything alone when the number is unchanged' do
    delivery = fulfillment.primary_delivery
    delivery.update!(tracking_url: 'https://kept.example/t/1')
    delivery.update_columns(status: 'in_transit')

    service.call(fulfillment: fulfillment, tracking: delivery.tracking_number)

    expect(delivery.reload.status).to eq('in_transit')
    expect(delivery.tracking_url).to eq('https://kept.example/t/1')
  end
end
