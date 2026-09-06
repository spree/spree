require 'spec_helper'

RSpec.describe Spree::DeliveryRateProvider::Freight do
  let(:store) { @default_store }
  let(:carton) { create(:carton_package_type, store: store, length: 40, width: 30, height: 25) }
  let(:variant) { create(:variant, units_per_carton: 12, cartons_per_pallet: 40, carton_package_type: carton) }
  let(:delivery_method) do
    create(:delivery_method, store: store, name: 'Pallet freight',
                             rate_provider: described_class.name)
  end
  let(:package) do
    order = create(:order, store: store)
    create(:line_item, order: order, variant: variant, quantity: 24)
    Spree::Stock::Coordinator.new(order.reload).packages.first
  end

  subject(:provider) { described_class.new(delivery_method) }

  it 'quotes a rate with no price rather than a free one' do
    estimate = provider.estimate(package)

    expect(estimate.unpriced).to be(true)
    expect(estimate.cost).to be_zero
  end

  it 'names the rate after the method the merchant configured' do
    expect(provider.estimate(package).name).to eq('Pallet freight')
  end

  # What the merchant sends the forwarder in place of a price.
  it 'carries the freight summary the forwarder will quote against' do
    summary = provider.estimate(package).metadata['freight_summary']

    expect(summary['total_units']).to eq(24)
    expect(summary['total_cartons']).to eq(2)
    expect(summary['total_pallets']).to eq(1)
    expect(summary['complete']).to be(true)
  end

  it 'ships to an address and never consults a calculator' do
    expect(described_class.requires_address?).to be(true)
    expect(described_class.uses_calculator?).to be(false)
  end

  it 'is registered as a selectable rate provider' do
    expect(Spree.delivery_rate_providers).to include(described_class)
  end
end
