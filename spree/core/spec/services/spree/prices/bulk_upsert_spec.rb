require 'spec_helper'

RSpec.describe Spree::Prices::BulkUpsert do
  let(:store) { @default_store }
  let(:price_list) { create(:price_list, store: store) }
  let(:product) { create(:product, stores: [store]) }
  let!(:variant) { create(:variant, product: product) }
  let!(:override) do
    create(:price, variant: variant, price_list: price_list, currency: 'USD', amount: BigDecimal('5.00'))
  end

  describe '#call' do
    it 'returns zero count on empty input without touching the DB' do
      expect(Spree::Price).not_to receive(:upsert_all)
      result = described_class.call(rows: [])

      expect(result).to be_success
      expect(result.value).to eq(price_count: 0)
    end

    it 'updates a price-list override in a single upsert_all call' do
      expect(Spree::Price).to receive(:upsert_all).once.and_call_original

      result = described_class.call(
        rows: [{
          variant_id: variant.id,
          currency: 'USD',
          price_list_id: price_list.id,
          amount: '19.99',
          compare_at_amount: '24.99'
        }]
      )

      expect(result).to be_success
      expect(result.value).to eq(price_count: 1)
      expect(override.reload).to have_attributes(
        amount: BigDecimal('19.99'),
        compare_at_amount: BigDecimal('24.99')
      )
    end

    it 'creates a new row when no match exists' do
      other_variant = create(:variant, product: product)

      result = described_class.call(
        rows: [{
          variant_id: other_variant.id,
          currency: 'EUR',
          price_list_id: price_list.id,
          amount: '4.20'
        }]
      )

      expect(result).to be_success
      expect(result.value).to eq(price_count: 1)
      row = Spree::Price.find_by(
        variant_id: other_variant.id, currency: 'EUR', price_list_id: price_list.id
      )
      expect(row).not_to be_nil
      expect(row.amount).to eq(BigDecimal('4.20'))
    end

    it 'drops rows missing variant_id or currency' do
      result = described_class.call(rows: [{ amount: '9.99' }])

      expect(result).to be_success
      expect(result.value).to eq(price_count: 0)
    end

    it 'leaves exactly one real-amount row when filling in a placeholder' do
      placeholder_variant = create(:variant, product: product)
      create(:price, variant: placeholder_variant, price_list: price_list, currency: 'USD', amount: nil)

      result = described_class.call(
        rows: [{
          variant_id: placeholder_variant.id,
          currency: 'USD',
          price_list_id: price_list.id,
          amount: '12.34'
        }]
      )

      expect(result).to be_success
      surviving = Spree::Price.where(
        variant_id: placeholder_variant.id, currency: 'USD', price_list_id: price_list.id
      )
      expect(surviving.count).to eq(1)
      expect(surviving.first.amount).to eq(BigDecimal('12.34'))
    end
  end
end
