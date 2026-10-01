require 'spec_helper'

RSpec.describe Spree::Seeds::StoreResources do
  let(:store) { create(:store, default_currency: 'EUR') }
  let!(:other_store) { create(:store) }

  let(:seeded_counts) do
    lambda do |seeded_store|
      {
        tax_categories: seeded_store.tax_categories.count,
        channels: seeded_store.channels.count,
        roles: Spree::Role.for_resource(seeded_store).count,
        delivery_methods: Spree::DeliveryMethod.where(store: seeded_store).count,
        payment_methods: seeded_store.payment_methods.count,
        product_types: Spree::ProductType.where(store: seeded_store).count,
        customer_groups: seeded_store.customer_groups.count,
        return_reasons: Spree::ReturnReason.where(store: seeded_store).count,
        commission_rates: seeded_store.commission_rates.count,
        seller_requirements: seeded_store.seller_requirements.count,
        api_keys: seeded_store.api_keys.count,
        saved_reports: seeded_store.saved_reports.count,
        allowed_origins: seeded_store.allowed_origins.count
      }
    end
  end

  it 'seeds the given store and leaves every other store untouched' do
    other_before = seeded_counts.call(other_store)
    default_before = seeded_counts.call(@default_store)

    described_class.call(store: store)

    expect(seeded_counts.call(store).values).to all(be_positive)
    expect(seeded_counts.call(other_store)).to eq(other_before)
    expect(seeded_counts.call(@default_store)).to eq(default_before)
  end

  it 'is idempotent' do
    described_class.call(store: store)

    expect { described_class.call(store: store) }.not_to(change { seeded_counts.call(store) })
  end

  it "prices digital delivery in the store's own currency" do
    described_class.call(store: store)

    digital = Spree::DeliveryMethod.find_by!(store: store, fulfillment_provider: 'Spree::FulfillmentProvider::Digital')
    expect(digital.calculator.preferred_currency).to eq('EUR')
  end

  it 'refuses to run without a store' do
    expect { described_class.call(store: nil) }.to raise_error(ArgumentError)
  end
end
