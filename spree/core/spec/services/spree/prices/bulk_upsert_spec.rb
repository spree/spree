require 'spec_helper'

RSpec.describe Spree::Prices::BulkUpsert do
  let(:store) { @default_store }
  let(:price_list) { create(:price_list, store: store) }
  let(:product) { create(:product) }
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

  # The cap lives here because every write path reaches this service and none
  # of them run model validations (docs/plans/6.0-volume-pricing.md).
  describe 'the quantity-break cap' do
    let(:price_list) { create(:price_list, store: @default_store) }
    let(:variant) { create(:variant) }

    def rung(quantity, amount = '9.00')
      { variant_id: variant.id, currency: 'USD', price_list_id: price_list.id,
        min_quantity: quantity, amount: amount }
    end

    it 'refuses a batch that would take a variant past the cap' do
      result = described_class.call(rows: (2..(Spree::Price::MAXIMUM_BREAKS_PER_VARIANT + 2)).map { |q| rung(q) })

      expect(result).to be_failure
      expect(result.error.value[:over_cap].first).to include(variant_id: variant.id.to_s)
      expect(Spree::Price.where(price_list: price_list).breaks).to be_empty
    end

    it 'accepts a ladder exactly at the cap, bottom rung included' do
      rows = [rung(1, '10.00')] + (2..(Spree::Price::MAXIMUM_BREAKS_PER_VARIANT + 1)).map { |q| rung(q) }

      expect(described_class.call(rows: rows)).to be_success
      expect(Spree::Price.where(price_list: price_list, variant: variant).count).
        to eq(Spree::Price::MAXIMUM_BREAKS_PER_VARIANT + 1)
    end

    it 'lets a full ladder be rewritten in place' do
      rows = (2..(Spree::Price::MAXIMUM_BREAKS_PER_VARIANT + 1)).map { |q| rung(q) }
      described_class.call(rows: rows)

      expect(described_class.call(rows: rows.map { |row| row.merge(amount: '8.00') })).to be_success
    end

    # A merchant who drops two rungs and adds two others ends with the ladder
    # the size it began, so the batch carrying both must not be refused for
    # the rungs it is about to remove.
    it 'lets a full ladder swap rungs in one batch' do
      full = (2..(Spree::Price::MAXIMUM_BREAKS_PER_VARIANT + 1)).map { |q| rung(q) }
      described_class.call(rows: full)

      swap = [rung(2, nil), rung(3, nil), rung(500), rung(600)]

      expect(described_class.call(rows: swap)).to be_success
      expect(Spree::Price.where(price_list: price_list, variant: variant).breaks.count).
        to eq(Spree::Price::MAXIMUM_BREAKS_PER_VARIANT)
    end

    # Placeholders charge nothing, so they do not fill a ladder — the model's
    # own guard counts the same way.
    it 'does not count placeholder rungs against the cap' do
      (2..(Spree::Price::MAXIMUM_BREAKS_PER_VARIANT + 1)).each do |quantity|
        create(:price, variant: variant, currency: 'USD', price_list: price_list,
                       min_quantity: quantity, amount: nil)
      end

      expect(described_class.call(rows: [rung(500)])).to be_success
    end

    # Coercing a typo with `to_i` would make it quantity 1 and overwrite the
    # contracted price the variant is actually sold at.
    it 'refuses a batch whose quantity is not a whole number' do
      described_class.call(rows: [rung(1, '10.00')])

      result = described_class.call(rows: [rung('not-a-number', '1.11')])

      expect(result).to be_failure
      expect(result.error.value[:invalid_quantities]).to eq([{ index: 0 }])
      expect(Spree::Price.find_by(variant: variant, currency: 'USD', price_list: price_list, min_quantity: 1).amount).
        to eq(10)
    end

    it 'refuses a quantity below one' do
      expect(described_class.call(rows: [rung(0)])).to be_failure
      expect(described_class.call(rows: [rung(-5)])).to be_failure
    end

    # Two malformed rows must both be reported, not collapsed into one by the
    # dedup that keys on the coerced quantity.
    it 'names every offending row' do
      result = described_class.call(rows: [rung('x'), rung('y')])

      expect(result.error.value[:invalid_quantities]).to eq([{ index: 0 }, { index: 1 }])
    end

    # An absent quantity is the ladder's bottom rung, which is every row
    # written before breaks existed.
    it 'still accepts a row that names no quantity' do
      expect(described_class.call(rows: [{ variant_id: variant.id, currency: 'USD',
                                           price_list_id: price_list.id, amount: '10.00' }])).to be_success
    end

    # An ordinary spreadsheet save carries no breaks at all, and must not pay
    # for the check.
    it 'runs no cap query for a batch of bottom rungs' do
      expect(Spree::Price).not_to receive(:breaks)

      expect(described_class.call(rows: [rung(1, '10.00')])).to be_success
    end
  end
end
