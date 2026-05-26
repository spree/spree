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

    # Regression: a single bulk_upsert call can carry base-price rows
    # (price_list_id IS NULL) alongside overrides. The unique constraints
    # live in two separate partial indexes — one keyed on (variant_id,
    # currency) for base, one on the triple for overrides — so the service
    # must route each row to the right ON CONFLICT clause. Before the fix,
    # base rows hit the override index and crashed with RecordNotUnique.
    it 'updates an existing base price (price_list_id IS NULL)' do
      base = variant.prices.find_by!(currency: 'USD', price_list_id: nil)

      result = described_class.call(
        rows: [{ variant_id: variant.id, currency: 'USD', amount: '12.34' }]
      )

      expect(result).to be_success
      expect(base.reload.amount).to eq(BigDecimal('12.34'))
    end

    it 'handles base + override rows in the same call' do
      base = variant.prices.find_by!(currency: 'USD', price_list_id: nil)

      result = described_class.call(
        rows: [
          { variant_id: variant.id, currency: 'USD', amount: '7.77' },
          { variant_id: variant.id, currency: 'USD', price_list_id: price_list.id, amount: '8.88' }
        ]
      )

      expect(result).to be_success
      expect(result.value).to eq(price_count: 2)
      expect(base.reload.amount).to eq(BigDecimal('7.77'))
      expect(override.reload.amount).to eq(BigDecimal('8.88'))
    end

    it 'touches the variant (and via touch: true, the product) after an upsert' do
      Timecop.freeze(Time.current.change(usec: 0)) do
        variant.update_columns(updated_at: 1.day.ago)
        product.update_columns(updated_at: 1.day.ago)

        described_class.call(
          rows: [{ variant_id: variant.id, currency: 'USD', amount: '7.77' }]
        )

        expect(variant.reload.updated_at).to eq(Time.current)
        expect(product.reload.updated_at).to eq(Time.current)
      end
    end

    # Regression: the base-row update loop pulls existing rows via
    # `WHERE variant_id IN (...) AND currency IN (...)`, which returns
    # cross-pairs (variant_a + EUR, variant_b + USD) that the caller never
    # asked about. The loop must skip those instead of crashing on a nil
    # row when it looks up the request hash.
    it 'tolerates cross-pair matches in the existing-base-row lookup' do
      other_variant = create(:variant, product: product)
      # Seed an unrelated base price the cross-pair `IN` query will catch.
      create(:price, variant: other_variant, currency: 'EUR', amount: 99.0, price_list_id: nil)

      result = described_class.call(
        rows: [
          { variant_id: variant.id, currency: 'USD', amount: '7.77' },
          { variant_id: other_variant.id, currency: 'USD', amount: '8.88' }
        ]
      )

      expect(result).to be_success
      base = variant.prices.find_by!(currency: 'USD', price_list_id: nil)
      expect(base.amount).to eq(BigDecimal('7.77'))
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
