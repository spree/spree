require 'spec_helper'

RSpec.describe Spree::Exports::PriceListPrices, type: :model do
  let(:store) { @default_store }
  let(:price_list) { create(:price_list, store: store) }
  let(:other_list) { create(:price_list, store: store) }
  let(:user) { create(:admin_user) }

  def build_export(search_params: { price_list_id_eq: price_list.prefixed_id }, record_selection: 'filtered')
    described_class.new(store: store, user: user, search_params: search_params, record_selection: record_selection)
  end

  describe 'validation' do
    it 'needs a price list of the store' do
      expect(build_export).to be_valid
      expect(build_export(search_params: nil)).not_to be_valid
      expect(build_export(record_selection: 'all')).not_to be_valid

      foreign = create(:price_list, store: create(:store))
      expect(build_export(search_params: { price_list_id_eq: foreign.prefixed_id })).not_to be_valid
    end
  end

  describe '#generate_csv' do
    let(:product) { create(:product, name: 'Denim Shirt', store: store) }
    let(:variant) { create(:variant, product: product, sku: 'DENIM-M') }
    let(:other_variant) { create(:variant, product: product, sku: 'DENIM-L') }

    before do
      create(:price, variant: variant, price_list: price_list, currency: 'USD', min_quantity: 96, amount: 15)
      create(:price, variant: variant, price_list: price_list, currency: 'USD', min_quantity: 1, amount: 18)
      create(:price, variant: variant, price_list: price_list, currency: 'USD', min_quantity: 24, amount: 16.5)
      create(:price, variant: variant, price_list: price_list, currency: 'EUR', min_quantity: 1, amount: 17)
      # A placeholder: on the list, not priced.
      create(:price, variant: other_variant, price_list: price_list, currency: 'USD', min_quantity: 1, amount: nil)
      # Another list's row is not this list's, and neither is the variant's
      # own base price (the factory already created one).
      create(:price, variant: variant, price_list: other_list, currency: 'USD', min_quantity: 1, amount: 9)
    end

    it 'writes the selected list\'s priced rungs, ladders in quantity order' do
      export = build_export
      export.save!
      export.generate

      rows = CSV.parse(export.attachment.download, headers: true)
      expect(rows.map { |row| row.to_h.values_at('sku', 'currency', 'min_quantity', 'price') }).to eq([
        ['DENIM-M', 'EUR', '1', '17.00'],
        ['DENIM-M', 'USD', '1', '18.00'],
        ['DENIM-M', 'USD', '24', '16.50'],
        ['DENIM-M', 'USD', '96', '15.00']
      ])
      expect(rows.headers).to eq(Spree::CSV::PriceListPricePresenter::HEADERS)
    end
  end

  it 'is gated by the products scope, like the price-list endpoints' do
    expect(described_class.required_scope).to eq(:products)
    expect(described_class.model_class).to eq(Spree::Price)
  end
end
