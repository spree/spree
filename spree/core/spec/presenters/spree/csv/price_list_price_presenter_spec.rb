require 'spec_helper'

RSpec.describe Spree::CSV::PriceListPricePresenter do
  let(:store) { @default_store }
  let(:price_list) { create(:price_list, store: store) }
  let(:product) { create(:product, name: 'Denim Shirt', store: store) }
  let(:variant) { create(:variant, product: product, sku: 'DENIM-M') }

  it 'writes one rung with the import schema headers' do
    price = create(:price, variant: variant, price_list: price_list, currency: 'USD', min_quantity: 24, amount: 16.5, compare_at_amount: nil)

    row = described_class.new(price).call

    expect(described_class::HEADERS).to eq(%w[sku currency min_quantity price compare_at_price])
    expect(row).to eq(['DENIM-M', 'USD', 24, '16.50', nil])
  end
end
