require 'spec_helper'

describe Spree::FulfillmentProvider::Base, type: :model do
  subject(:provider) { described_class.new }

  let(:fulfillment) { build(:fulfillment) }

  it 'allows fulfillment by default and does not auto-fulfill' do
    expect(provider.can_fulfill?(fulfillment)).to be(true)
    expect(provider.auto_fulfill?).to be(false)
    expect(provider.tracking_url(fulfillment)).to be_nil
    expect(provider.documents(fulfillment)).to eq([])
  end

  it 'requires create/cancel in subclasses' do
    expect { provider.create_fulfillment(fulfillment) }.to raise_error(NotImplementedError)
    expect { provider.cancel_fulfillment(fulfillment) }.to raise_error(NotImplementedError)
  end

  describe 'registry' do
    it 'exposes the built-in providers and fulfillment types' do
      expect(Spree.fulfillment_providers).to include(
        Spree::FulfillmentProvider::Manual,
        Spree::FulfillmentProvider::Digital,
        Spree::FulfillmentProvider::Pickup,
        Spree::FulfillmentProvider::PickupPoint
      )
      expect(Spree.fulfillment_types).to include('shipping', 'pickup', 'digital')
      # Deferred to 6.1: pickup_point (provider ships, type unregistered) and
      # local_delivery (no implementation — a shipping method with a
      # postal-code zone covers the use case today).
      expect(Spree.fulfillment_types).not_to include('pickup_point', 'local_delivery')
    end
  end

  describe 'Fulfillment#provider' do
    it 'falls back to Manual without a delivery method' do
      expect(build(:fulfillment).provider).to be_a(Spree::FulfillmentProvider::Manual)
    end
  end
end
