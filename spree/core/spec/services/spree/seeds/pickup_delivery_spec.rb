require 'spec_helper'

RSpec.describe Spree::Seeds::PickupDelivery do
  subject { described_class.call }

  let(:store) { @default_store }

  # The suite's shared store carries no locations, so the seed's subject —
  # a default counter to collect from — has to exist first.
  let!(:default_location) { create(:stock_location, store: store, default: true, pickup_enabled: false) }

  it 'creates a zoneless pickup method on the default profile' do
    subject

    delivery_method = store.delivery_methods.find_by(name: Spree.t('pickup.store_pickup'))

    expect(delivery_method).to be_present
    expect(delivery_method).to be_pickup
    expect(delivery_method.delivery_profile).to eq(store.default_delivery_profile)
    # Pickup has an origin, not a destination — a zone would wrongly filter it
    # against the customer's shipping address.
    expect(delivery_method.delivery_zone).to be_nil
    expect(delivery_method.requires_address?).to be false
  end

  it 'opens the default stock location for collection' do
    expect { subject }.to change { store.stock_locations.where(pickup_enabled: true).count }.from(0)
  end

  it 'leaves an existing pickup location choice alone' do
    counter = create(:stock_location, store: store, pickup_enabled: true, default: false)

    subject

    expect(store.stock_locations.where(pickup_enabled: true)).to eq([counter])
    expect(default_location.reload.pickup_enabled).to be false
  end

  it 'is idempotent' do
    described_class.call

    expect { subject }.not_to change(Spree::DeliveryMethod, :count)
  end
end
