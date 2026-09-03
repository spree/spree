require 'spec_helper'

RSpec.describe Spree::Deliveries::Create do
  subject(:service) { described_class.new }

  let(:store) { @default_store }
  let(:order) { create(:order_ready_to_ship, store: store) }
  let(:fulfillment) { order.fulfillments.first }

  it 'records a consignment on the owner, in the owner store, starting pending' do
    result = service.call(owner: fulfillment, tracking_number: ' 1Z879E930346834440 ')

    expect(result).to be_success
    delivery = result.value
    expect(delivery.store).to eq(store)
    expect(delivery.tracking_number).to eq('1Z879E930346834440')
    expect(delivery.status).to eq('pending')
    expect(delivery.carrier).to eq('ups')
    expect(fulfillment.reload.deliveries).to include(delivery)
  end

  it 'copies a pasted link into tracking_url' do
    result = service.call(owner: fulfillment, tracking_number: 'https://carrier.example/t/1')

    expect(result.value.read_attribute(:tracking_url)).to eq('https://carrier.example/t/1')
  end

  it 'refuses a duplicate number on the same owner' do
    service.call(owner: fulfillment, tracking_number: 'DUP-1')

    result = service.call(owner: fulfillment, tracking_number: 'DUP-1')

    expect(result).to be_failure
    expect(result.error.to_s).to include('Tracking number')
  end

  it 'works for a return owner' do
    return_record = create(:return, order: create(:shipped_order, store: store))

    result = service.call(owner: return_record, tracking_number: 'RET-1', carrier: 'Maersk')

    expect(result).to be_success
    expect(return_record.deliveries.first.carrier).to eq('Maersk')
  end
end
