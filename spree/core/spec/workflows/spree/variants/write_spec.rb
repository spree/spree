require 'spec_helper'

RSpec.describe 'Spree::Variants write workflows' do
  let(:store) { @default_store }
  let(:product) { create(:product, store: store) }
  let!(:stock_location) { create(:stock_location, store: store) }

  describe Spree::Variants::Create do
    it 'creates a variant on the product' do
      result = described_class.call(product: product, attributes: { sku: 'NEW-1' })

      expect(result).to be_success
      expect(result.value.sku).to eq('NEW-1')
      expect(result.value.product).to eq(product)
    end

    # The model defers these when it is built without an owner; the workflow
    # names the product up front, so they apply directly.
    it 'applies options, prices and stock in one call' do
      result = described_class.call(
        product: product,
        attributes: {
          sku: 'FULL-1',
          options: [{ name: 'Color', value: 'Red' }],
          prices: [{ currency: 'USD', amount: 12 }],
          stock_levels: [{ stock_location_id: stock_location.id, count_on_hand: 7 }]
        }
      )

      variant = result.value
      expect(result).to be_success
      expect(variant.option_values.map(&:label)).to include('Red')
      expect(variant.price_in('USD').amount).to eq(12)
      expect(variant.stock_levels.find_by(stock_location: stock_location).count_on_hand).to eq(7)
    end

    it 'can be vetoed before the variant is written' do
      Spree.hooks.clear!
      Spree.hooks.register('variants.create.validate') { |workflow| workflow.reject!('nope') }

      expect(described_class.call(product: product, attributes: { sku: 'VETO-1' })).not_to be_success
      expect(Spree::Variant.where(sku: 'VETO-1')).to be_empty
    ensure
      Spree.hooks.clear!
    end
  end

  describe Spree::Variants::Update do
    let(:variant) { create(:variant, product: product) }

    it 'updates plain attributes' do
      result = described_class.call(variant: variant, attributes: { sku: 'CHANGED' })

      expect(result).to be_success
      expect(variant.reload.sku).to eq('CHANGED')
    end

    # Prices replace: a currency missing from the payload loses its base price.
    it 'replaces prices' do
      variant.set_price('USD', 10)
      variant.set_price('EUR', 20)

      described_class.call(variant: variant, attributes: { prices: [{ currency: 'USD', amount: 15 }] })

      expect(variant.reload.price_in('USD').amount).to eq(15)
      expect(variant.price_in('EUR')&.amount).to be_nil
    end

    # Stock upserts: a warehouse missing from the payload keeps its stock,
    # because a partial payload must not silently destroy a shelf count.
    it 'leaves a stock level the payload does not mention' do
      other = create(:stock_location, store: store)
      variant.set_stock(5, nil, stock_location)
      variant.set_stock(3, nil, other)

      described_class.call(
        variant: variant,
        attributes: { stock_levels: [{ stock_location_id: stock_location.id, count_on_hand: 9 }] }
      )

      expect(variant.reload.stock_levels.find_by(stock_location: stock_location).count_on_hand).to eq(9)
      expect(variant.stock_levels.find_by(stock_location: other).count_on_hand).to eq(3)
    end

    # Spree::StockLocation lookup is global, so an id from another store must
    # not put this variant's stock in that store's warehouse.
    # The variant factory propagates into every existing stock location
    # regardless of store, so the foreign one is created after the variant to
    # keep this about what the workflow does rather than what the factory did.
    it 'ignores a stock location belonging to another store' do
      variant
      foreign = create(:stock_location, store: create(:store))
      levels_before = variant.reload.stock_levels.pluck(:stock_location_id).sort

      described_class.call(
        variant: variant,
        attributes: { stock_levels: [{ stock_location_id: foreign.id, count_on_hand: 4 }] }
      )

      expect(variant.reload.stock_levels.pluck(:stock_location_id).sort).to eq(levels_before)
      expect(variant.stock_levels.map(&:stock_location)).not_to include(foreign)
    end
  end
end
