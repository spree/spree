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

    # Below the $5.00 bottom rung these specs inherit from `override`: a cap
    # spec must build a ladder that is otherwise legal.
    def rung(quantity, amount = '4.00')
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

      expect(described_class.call(rows: rows.map { |row| row.merge(amount: '3.00') })).to be_success
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
  end

  # A quantity break that costs more than the quantity below it buys is the
  # opposite of what it says, and the resolver charges it without comparing
  # (docs/plans/6.0-volume-pricing.md).
  describe 'a ladder that charges more for a bigger order' do
    let(:price_list) { create(:price_list, store: @default_store) }
    let(:variant) { create(:variant, price: 39.99) }
    # These build their own ladders; the outer override would seed a bottom
    # rung none of them asked for.
    let!(:override) { nil }

    def rung(quantity, amount)
      { variant_id: variant.id, currency: 'USD', price_list_id: price_list.id,
        min_quantity: quantity, amount: amount }
    end

    it 'refuses a break priced above the rung below it' do
      result = described_class.call(rows: [rung(1, '30.00'), rung(100, '20.00'), rung(200, '25.00')])

      expect(result).to be_failure
      expect(result.error.value[:rising_ladders].first).to include(min_quantity: 200, floor: BigDecimal('20.00'))
      expect(Spree::Price.where(price_list: price_list, variant: variant)).to be_empty
    end

    # The reported bug: with no rung of its own the ladder's floor is the shop
    # price, which is what the buyer pays right up to the threshold.
    it 'refuses a break priced above the base price when the list has no bottom rung' do
      result = described_class.call(rows: [rung(100, '440.00')])

      expect(result).to be_failure
      expect(result.error.value[:rising_ladders].first).to include(min_quantity: 100, floor: BigDecimal('39.99'))
    end

    it 'accepts a break below the base price when the list has no bottom rung' do
      expect(described_class.call(rows: [rung(100, '35.00')])).to be_success
    end

    it 'accepts a descending ladder' do
      expect(described_class.call(rows: [rung(1, '30.00'), rung(100, '20.00'), rung(200, '15.00')])).to be_success
    end

    it 'accepts a ladder that holds one price at every quantity' do
      expect(described_class.call(rows: [rung(1, '30.00'), rung(100, '30.00')])).to be_success
    end

    # A merchant fixes the rung they are told to fix, so the one named is the
    # first breach reading upward — not a later pair that happens to be found
    # while walking the ladder.
    it 'names the bottom rung when it and a later pair both breach' do
      result = described_class.call(rows: [rung(25, '45.00'), rung(50, '50.00')])

      expect(result).to be_failure
      expect(result.error.value[:rising_ladders].first).to include(min_quantity: 25, floor: BigDecimal('39.99'))
    end

    # Lowering the shop price under a break raises the bill at the threshold
    # just as surely as mispricing the break, and the batch names no rung.
    it 'refuses a base price dropped below a stored break' do
      described_class.call(rows: [rung(100, '35.00')])

      result = described_class.call(rows: [{ variant_id: variant.id, currency: 'USD', amount: '10.00' }])

      expect(result).to be_failure
      expect(result.error.value[:rising_ladders].first).to include(min_quantity: 100)
      expect(variant.prices.find_by(price_list_id: nil, currency: 'USD').amount).to eq(BigDecimal('39.99'))
    end

    # Removing the bottom rung drops the ladder onto the shop price, and the
    # batch carries nothing but the removal.
    it 'refuses a cleared bottom rung that leaves a break above the base price' do
      # Legal as it stands: the bottom rung may sit above the $39.99 base, and
      # the break undercuts it. Removing the bottom rung drops the break onto
      # the base, which it does not undercut.
      described_class.call(rows: [rung(1, '50.00'), rung(100, '45.00')])

      expect(described_class.call(rows: [rung(1, nil)])).to be_failure
      expect(Spree::Price.find_by(variant: variant, price_list: price_list, min_quantity: 1)&.amount).to eq(50)
    end

    # No write path can leave a ladder rising, so one found rising was planted
    # from outside them — raw SQL, or data predating the rule. It is repaired
    # rather than built on: every save is judged on the state it would leave.
    it 'refuses to build on a ladder that is already rising' do
      Spree::Price.insert_all!([{ variant_id: variant.id, currency: 'USD', price_list_id: price_list.id,
                                  min_quantity: 1, amount: 30, created_at: Time.current, updated_at: Time.current },
                                { variant_id: variant.id, currency: 'USD', price_list_id: price_list.id,
                                  min_quantity: 200, amount: 45, created_at: Time.current, updated_at: Time.current }])

      # Editing elsewhere, and adding a rung above the breach, both leave it standing.
      expect(described_class.call(rows: [rung(1, '28.00')])).to be_failure
      expect(described_class.call(rows: [rung(300, '50.00')])).to be_failure

      # Repairing the offending rung is what the merchant can always do.
      expect(described_class.call(rows: [rung(200, '20.00')])).to be_success
    end

    # An agreement is free to be dearer than the shop; only a break promises a
    # better price for a bigger order.
    it 'accepts a bottom rung above the base price' do
      expect(described_class.call(rows: [rung(1, '99.00')])).to be_success
      expect(described_class.call(rows: [rung(1, '99.00'), rung(100, '50.00')])).to be_success
    end

    it 'reads the rungs already stored, not only the batch' do
      described_class.call(rows: [rung(1, '30.00'), rung(100, '20.00')])

      expect(described_class.call(rows: [rung(200, '25.00')])).to be_failure
      expect(described_class.call(rows: [rung(200, '15.00')])).to be_success
    end

    # Removing the bottom rung drops the ladder onto the shop price, so the
    # break it leaves behind is measured against that instead.
    it 'measures against the base price when the batch clears the bottom rung' do
      described_class.call(rows: [rung(1, '30.00'), rung(100, '20.00')])

      expect(described_class.call(rows: [rung(1, nil), rung(100, '45.00')])).to be_failure
      expect(described_class.call(rows: [rung(1, nil), rung(100, '20.00')])).to be_success
    end

    # A merchant lowering the shop price and adding a break in one save is
    # judged on the pair they sent, not on the price being replaced.
    it 'compares against a base price the same batch writes' do
      rows = [{ variant_id: variant.id, currency: 'USD', amount: '10.00' }, rung(100, '20.00')]

      expect(described_class.call(rows: rows)).to be_failure
    end

    it 'leaves a ladder on another list alone' do
      other = create(:price_list, store: @default_store)
      rows = [rung(1, '30.00'), rung(100, '20.00'),
              { variant_id: variant.id, currency: 'USD', price_list_id: other.id,
                min_quantity: 100, amount: '45.00' }]

      result = described_class.call(rows: rows)

      expect(result).to be_failure
      expect(result.error.value[:rising_ladders].map { |l| l[:price_list_id] }).to eq([other.id.to_s])
    end
  end

  # Two prices at one quantity is a merchant meaning one of them; keeping the
  # later one silently discards the other (docs/plans/6.0-volume-pricing.md).
  describe 'two rows addressing one rung' do
    let(:price_list) { create(:price_list, store: @default_store) }
    let(:variant) { create(:variant, price: 39.99) }
    # These build their own ladders; the outer override would seed a bottom
    # rung none of them asked for.
    let!(:override) { nil }

    def rung(quantity, amount)
      { variant_id: variant.id, currency: 'USD', price_list_id: price_list.id,
        min_quantity: quantity, amount: amount }
    end

    it 'refuses the batch and names the repeated quantity' do
      result = described_class.call(rows: [rung(1, '30.00'), rung(100, '10.00'), rung(100, '25.00')])

      expect(result).to be_failure
      expect(result.error.value[:duplicate_quantities]).to eq([{ index: 2, min_quantity: 100 }])
      expect(Spree::Price.where(price_list: price_list, variant: variant)).to be_empty
    end

    # An absent quantity is the bottom rung, so it collides with an explicit 1.
    it 'counts an absent quantity as the bottom rung' do
      rows = [{ variant_id: variant.id, currency: 'USD', price_list_id: price_list.id, amount: '30.00' },
              rung(1, '25.00')]

      expect(described_class.call(rows: rows)).to be_failure
    end

    # The editor sends a moved rung plus a clear for the row it left behind, so
    # a chain of moves lands both on one quantity. That is one rung, not two.
    it 'takes the amount when a rung moves onto a quantity the batch clears' do
      described_class.call(rows: [rung(10, '30.00'), rung(50, '20.00')])

      result = described_class.call(rows: [rung(50, '30.00'), rung(10, nil), rung(100, '20.00'), rung(50, nil)])

      expect(result).to be_success
      expect(Spree::Price.where(price_list: price_list, variant: variant).where.not(amount: nil).
             order(:min_quantity).pluck(:min_quantity, :amount)).to eq([[50, 30.0], [100, 20.0]])
    end

    # Base prices upsert on `(variant_id, currency)` alone, so a quantity here
    # addresses a key it does not describe — and PG rejects the statement.
    # Reported under its own key: "must be a whole number" says nothing to
    # someone who sent 2.
    it 'refuses a base-price row that names a quantity' do
      rows = [{ variant_id: variant.id, currency: 'USD', min_quantity: 1, amount: '10.00' },
              { variant_id: variant.id, currency: 'USD', min_quantity: 2, amount: '9.00' }]

      result = described_class.call(rows: rows)

      expect(result).to be_failure
      expect(result.error.value[:quantities_on_base_prices]).to eq([{ index: 1 }])
    end

    # The documented CSV contract: a blank quantity and an explicit 1 both mean
    # the variant's regular price.
    it 'accepts a base-price row whose quantity is 1' do
      expect(described_class.call(rows: [{ variant_id: variant.id, currency: 'USD', min_quantity: 1, amount: '10.00' }])).
        to be_success
    end

    # One writer decodes ids to Integer and another leaves them as String; left
    # raw, the same rung reads as two keys and PG rejects the statement.
    it 'counts ids of different Ruby types as one rung' do
      rows = [rung(100, '30.00'),
              { variant_id: variant.id.to_s, currency: 'USD', price_list_id: price_list.id.to_s,
                min_quantity: 100, amount: '20.00' }]

      expect(described_class.call(rows: rows)).to be_failure
    end

    it 'lets one quantity appear once on each of two lists' do
      other = create(:price_list, store: @default_store)
      rows = [rung(100, '30.00'),
              { variant_id: variant.id, currency: 'USD', price_list_id: other.id,
                min_quantity: 100, amount: '25.00' }]

      expect(described_class.call(rows: rows)).to be_success
    end
  end
end
