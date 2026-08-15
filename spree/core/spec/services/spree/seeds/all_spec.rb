require 'spec_helper'

RSpec.describe Spree::Seeds::All do
  subject { described_class.call }

  it 'runs without raising errors' do
    expect { subject }.not_to raise_error
  end

  # CI seeds a fresh app and re-seeds on rerun; a seed whose finder includes
  # mutable attributes stops matching once anything edits them and then tries
  # to create a duplicate.
  it 'is idempotent when the seeded data has since been edited' do
    subject

    store = Spree::Store.find_by(default: true)
    store.tax_categories.update_all(is_default: false)

    expect { described_class.call }.not_to raise_error
    expect(store.tax_categories.where(name: 'Default').count).to eq(1)
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

    # The warehouse, delivery zones and pickup are deliberately absent: their
    # shape depends on a country nobody has named yet. First-run setup (or the
    # env-credential seed path) provisions them from the merchant's answer.
    it 'leaves the country-shaped defaults to first-run setup' do
      subject

      store = Spree::Store.find_by(default: true)

      expect(store.stock_locations).to be_empty
      expect(store.delivery_zones).to be_empty
      expect(store.delivery_methods.select(&:pickup?)).to be_empty
    end
  end
end
