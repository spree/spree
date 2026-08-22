require 'spec_helper'

RSpec.describe Spree::Imports::RowProcessors::Price do
  let(:store) { @default_store }
  let(:import) { create(:import, type: 'Spree::Imports::Prices', owner: store) }
  let(:product) { create(:product, store: store) }
  let!(:variant) { create(:variant, product: product, sku: 'WIDGET-1', price: 10) }

  def process(attributes)
    row = instance_double(Spree::ImportRow, import: import, to_schema_hash: attributes.stringify_keys)
    described_class.new(row).process!
  end

  it 'sets the base price for a currency' do
    process(sku: 'WIDGET-1', currency: 'USD', amount: '25.50')

    expect(variant.prices.base_prices.find_by(currency: 'USD').amount).to eq(25.50)
  end

  it 'adds a currency the variant did not have' do
    process(sku: 'WIDGET-1', currency: 'EUR', amount: '19.00')

    expect(variant.prices.reload.base_prices.find_by(currency: 'EUR').amount).to eq(19.00)
  end

  it 'records a compare-at price alongside' do
    process(sku: 'WIDGET-1', currency: 'USD', amount: '20', compare_at_amount: '30')

    expect(variant.prices.base_prices.find_by(currency: 'USD').compare_at_amount).to eq(30)
  end

  # "We no longer sell this here" and "this is free" are different statements,
  # so a blank amount removes the price rather than writing zero.
  it 'clears the price when the feed sends a blank amount' do
    variant.set_price('EUR', 19)

    process(sku: 'WIDGET-1', currency: 'EUR', amount: '')

    expect(variant.prices.reload.base_prices.find_by(currency: 'EUR')).to be_nil
  end

  it 'writes onto a named price list rather than the base price' do
    price_list = create(:price_list, store: store, name: 'Trade')

    process(sku: 'WIDGET-1', currency: 'USD', amount: '8', price_list: 'Trade')

    expect(variant.prices.reload.find_by(price_list_id: price_list.id).amount).to eq(8)
    expect(variant.prices.base_prices.find_by(currency: 'USD').amount).to eq(10)
  end

  it 'finds the variant by the key the feeding system holds' do
    variant.set_external_id('pim', 'SKU-XYZ')

    process(external_id: 'SKU-XYZ', external_system: 'pim', currency: 'USD', amount: '33')

    expect(variant.prices.reload.base_prices.find_by(currency: 'USD').amount).to eq(33)
  end

  describe 'rows that name something unknown' do
    it 'says which SKU it could not find' do
      expect { process(sku: 'NOPE', currency: 'USD', amount: '1') }.to raise_error(ArgumentError, /NOPE/)
    end

    it 'says which price list it could not find' do
      expect { process(sku: 'WIDGET-1', currency: 'USD', amount: '1', price_list: 'Ghost') }.
        to raise_error(ArgumentError, /Ghost/)
    end

    # Active Record casts a bad string to zero and stops at the first
    # non-numeric character, so a European "12,50" would import as 1250.00 —
    # a hundredfold overcharge nothing would report.
    it 'refuses an amount that is not a number rather than coercing it' do
      expect { process(sku: 'WIDGET-1', currency: 'USD', amount: 'abc') }.
        to raise_error(ArgumentError, /amount must be a number/)
    end

    it 'refuses a comma-decimal amount rather than reading it as thousands' do
      expect { process(sku: 'WIDGET-1', currency: 'USD', amount: '12,50') }.
        to raise_error(ArgumentError, /amount must be a number/)
    end

    it 'asks for a currency rather than guessing one' do
      expect { process(sku: 'WIDGET-1', amount: '1') }.to raise_error(ArgumentError, /Currency/)
    end
  end
end
