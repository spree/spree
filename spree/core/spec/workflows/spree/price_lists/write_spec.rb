require 'spec_helper'

RSpec.describe 'Spree::PriceLists write workflows' do
  let(:store) { @default_store }
  let(:product) { create(:product, store: store) }
  let(:variant) { product.default_variant }

  describe Spree::PriceLists::Create do
    it 'creates the list' do
      result = described_class.call(store: store, attributes: { name: 'Wholesale' })

      expect(result).to be_success
      expect(result.value.name).to eq('Wholesale')
      expect(result.value.status).to eq('draft')
    end

    it 'applies the product membership it was created with' do
      result = described_class.call(
        store: store, attributes: { name: 'Wholesale', product_ids: [product.id] }
      )

      expect(result.value.product_ids).to eq([product.id])
    end

    it 'fails on an invalid list without applying membership' do
      result = described_class.call(store: store, attributes: { product_ids: [product.id] })

      expect(result).not_to be_success
    end
  end

  describe Spree::PriceLists::Update do
    let(:price_list) { create(:price_list, store: store) }

    it 'updates plain attributes' do
      result = described_class.call(price_list: price_list, attributes: { name: 'Renamed' })

      expect(result).to be_success
      expect(price_list.reload.name).to eq('Renamed')
    end

    it 'accepts a string-keyed payload' do
      result = described_class.call(price_list: price_list, attributes: { 'name' => 'StringKeys' })

      expect(result).to be_success
      expect(price_list.reload.name).to eq('StringKeys')
    end

    # Prefixed ids arrive from the console and legacy callers; comparing them
    # against integer primary keys would read as "remove everything".
    it 'accepts prefixed product ids' do
      described_class.call(price_list: price_list, attributes: { product_ids: [product.prefixed_id] })

      expect(price_list.product_ids).to eq([product.id])
    end

    it 'adds and removes products' do
      other = create(:product, store: store)

      described_class.call(price_list: price_list, attributes: { product_ids: [product.id, other.id] })
      expect(price_list.product_ids).to match_array([product.id, other.id])

      described_class.call(price_list: price_list, attributes: { product_ids: [product.id] })
      expect(price_list.product_ids).to eq([product.id])
    end

    it 'upserts the price overrides it is given' do
      described_class.call(price_list: price_list, attributes: { product_ids: [product.id] })

      described_class.call(
        price_list: price_list,
        attributes: { prices: [{ variant_id: variant.id, currency: 'USD', amount: 5 }] }
      )

      price = price_list.prices.find_by(variant_id: variant.id, currency: 'USD')
      expect(price.amount).to eq(5)
    end

    # An empty array means "clear every override", which is a different
    # instruction from sending no prices at all.
    it 'clears every override when given an empty prices array' do
      described_class.call(price_list: price_list, attributes: { product_ids: [product.id] })
      described_class.call(
        price_list: price_list,
        attributes: { prices: [{ variant_id: variant.id, currency: 'USD', amount: 5 }] }
      )

      described_class.call(price_list: price_list, attributes: { prices: [] })

      expect(price_list.prices.where.not(amount: nil)).to be_empty
    end

    it 'leaves prices alone when the payload carries none' do
      described_class.call(price_list: price_list, attributes: { product_ids: [product.id] })
      described_class.call(
        price_list: price_list,
        attributes: { prices: [{ variant_id: variant.id, currency: 'USD', amount: 5 }] }
      )

      described_class.call(price_list: price_list, attributes: { name: 'Renamed' })

      expect(price_list.prices.find_by(variant_id: variant.id, currency: 'USD').amount).to eq(5)
    end

    context 'hooks' do
      before { Spree.hooks.clear! }
      after { Spree.hooks.clear! }

      it 'can be vetoed before anything is written' do
        Spree.hooks.register('price_lists.update.validate') { |workflow| workflow.reject!('nope') }

        result = described_class.call(price_list: price_list, attributes: { name: 'Renamed' })

        expect(result).not_to be_success
        expect(price_list.reload.name).not_to eq('Renamed')
      end
    end
  end
end
