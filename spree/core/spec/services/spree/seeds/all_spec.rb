require 'spec_helper'

RSpec.describe Spree::Seeds::All do
  subject { described_class.call }

  it 'runs without raising errors' do
    expect { subject }.not_to raise_error
  end

  # Store-scoped seeds iterate `Spree::Store.all`, so one ordered before
  # `Stores` silently creates nothing on a fresh install. The per-seed specs
  # can't catch it — they run against a suite that already has a store.
  context 'on a fresh install, with no store yet', :without_global_store do
    it 'gives the seeded store its store-scoped vocabularies' do
      subject

      store = Spree::Store.find_by(default: true)
      expect(Spree::ReturnReason.where(store: store).count).to eq(Spree::Seeds::ReturnsEnvironment::RETURN_REASONS.count)
      expect(Spree::ClaimReason.where(store: store).count).to eq(Spree::Seeds::ReturnsEnvironment::CLAIM_REASONS.count)
      expect(Spree::RefundReason.where(store: store)).to exist
      expect(Spree::ProductType.where(store: store)).to exist
    end

    it 'gives the seeded store a digital profile holding the digital delivery method' do
      subject

      store = Spree::Store.find_by(default: true)
      profile = Spree::DeliveryProfiles::Digital.find_by(store: store)

      expect(profile).to be_present
      expect(profile.delivery_methods.map(&:fulfillment_provider)).to eq(['Spree::FulfillmentProvider::Digital'])
    end

    it 'gives the seeded store a pickup method with a collectable location' do
      subject

      store = Spree::Store.find_by(default: true)

      expect(store.delivery_methods.select(&:pickup?)).to be_present
      expect(store.stock_locations.where(pickup_enabled: true)).to exist
    end
  end
end
