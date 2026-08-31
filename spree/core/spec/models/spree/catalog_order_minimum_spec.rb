require 'spec_helper'

RSpec.describe Spree::CatalogOrderMinimum do
  let(:store) { @default_store }
  let(:catalog) { create(:catalog, store: store) }

  it 'upcases the currency it is given' do
    minimum = create(:catalog_order_minimum, catalog: catalog, currency: 'usd')

    expect(minimum.currency).to eq('USD')
  end

  it 'refuses a second row for the same currency' do
    create(:catalog_order_minimum, catalog: catalog, currency: 'USD')

    expect(build(:catalog_order_minimum, catalog: catalog, currency: 'USD')).not_to be_valid
  end

  it 'enforces the per-currency uniqueness in the database as well' do
    create(:catalog_order_minimum, catalog: catalog, currency: 'USD')

    expect {
      described_class.new(catalog: catalog, currency: 'USD', amount: 100).save(validate: false)
    }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it 'allows the same catalog a row in another currency' do
    create(:catalog_order_minimum, catalog: catalog, currency: 'USD')

    expect(build(:catalog_order_minimum, catalog: catalog, currency: 'EUR')).to be_valid
  end

  it 'refuses a zero amount' do
    expect(build(:catalog_order_minimum, catalog: catalog, amount: 0)).not_to be_valid
  end
end
