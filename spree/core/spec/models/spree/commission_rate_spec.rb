require 'spec_helper'

RSpec.describe Spree::CommissionRate, type: :model do
  let(:store) { @default_store }

  describe 'validations' do
    # A flat fee is an amount, so it says which currency through its per-currency
    # rows. A percentage is a ratio and needs no currency at all.
    it 'requires an amount somewhere on a fixed rate but not on a percentage' do
      expect(build(:commission_rate, kind: 'fixed')).not_to be_valid
      expect(build(:commission_rate, kind: 'percentage')).to be_valid
    end

    # The override takes precedence over the store default, so it needs the
    # same bound: it is multiplied straight into what a seller is charged.
    it 'refuses a commission tax rate above one' do
      expect(build(:commission_rate, commission_tax_rate: 21)).not_to be_valid
      expect(build(:commission_rate, commission_tax_rate: 0.21)).to be_valid
    end

    it 'rejects a cap below the floor' do
      rate = create(:commission_rate, store: store)
      value = rate.commission_rate_values.build(currency: 'USD', min_amount: 10, max_amount: 5)

      expect(value).not_to be_valid
      expect(value.errors[:max_amount]).to be_present
    end

    it 'scopes the code to the store' do
      create(:commission_rate, store: store, code: 'standard')
      other_store = create(:store)

      expect(build(:commission_rate, store: store, code: 'standard')).not_to be_valid
      expect(build(:commission_rate, store: other_store, code: 'standard')).to be_valid
    end

    # Rates are paranoid, so the unique index has to ignore deleted rows or a
    # store could never reuse the code of a rate it had retired.
    it 'lets a store reuse the code of a rate it retired' do
      create(:commission_rate, store: store, code: 'standard').destroy

      expect { create(:commission_rate, store: store, code: 'standard') }.not_to raise_error
    end

    # The validation is case-insensitive, so the stored value has to be too —
    # otherwise the index would let "Foo" past "foo" on a concurrent write.
    it 'stores a code in one case, so the database enforces what the validation promises' do
      rate = create(:commission_rate, store: store, code: '  Standard  ')

      expect(rate.code).to eq('standard')
      expect(build(:commission_rate, store: store, code: 'STANDARD')).not_to be_valid
    end

    it 'allows several rates to carry no code at all' do
      create(:commission_rate, store: store, code: nil)

      expect { create(:commission_rate, store: store, code: nil) }.not_to raise_error
    end
  end

  describe '#applies_to_currency?' do
    it 'accepts any currency for a percentage' do
      rate = build(:commission_rate, kind: 'percentage')

      expect(rate.applies_to_currency?('EUR')).to be true
      expect(rate.applies_to_currency?('USD')).to be true
    end

    # A flat fee charges what it states, where it states it. Converting one
    # currency's figure into another would invent a fee nobody set, so a sale
    # in an unstated currency falls through to the next rate.
    it 'holds a flat fee to the currencies it states an amount in' do
      rate = create(:commission_rate, :fixed, store: store, amounts: { 'USD' => 5, 'GBP' => 4 })

      expect(rate.applies_to_currency?('usd')).to be true
      expect(rate.applies_to_currency?('GBP')).to be true
      expect(rate.applies_to_currency?('EUR')).to be false
    end

    # Capping the dollar fee is not a statement that euro sales earn nothing.
    # The percentage still charges; only the bound stays behind.
    it 'still charges a percentage in a currency it set no bounds for' do
      rate = create(:commission_rate, store: store, bounds: { 'USD' => { max_amount: 20 } })

      expect(rate.applies_to_currency?('EUR')).to be true
    end
  end

  describe 'floors and caps' do
    it 'reads each bound in its own currency' do
      rate = create(:commission_rate, store: store,
                    bounds: { 'USD' => { min_amount: 2, max_amount: 20 },
                              'PLN' => { max_amount: 80 } })

      expect(rate.min_amount_for('usd')).to eq(2)
      expect(rate.max_amount_for('USD')).to eq(20)
      expect(rate.min_amount_for('PLN')).to be_nil
      expect(rate.max_amount_for('EUR')).to be_nil
    end

    it 'reports only the currencies it bounds' do
      rate = create(:commission_rate, store: store, bounds: { 'USD' => { max_amount: 20 } })

      expect(rate.bounds.keys).to eq(['USD'])
    end

    # Bounds and flat fee amounts share a row, and are written by two different
    # fields. Neither write may quietly erase the other.
    it 'keeps a flat fee when its bounds are cleared' do
      rate = create(:commission_rate, :fixed, store: store, amounts: { 'USD' => 5 },
                    bounds: { 'USD' => { max_amount: 20 } })

      rate.update!(bounds: {})

      expect(rate.amount_for('USD')).to eq(5)
      expect(rate.max_amount_for('USD')).to be_nil
    end

    it 'keeps a bound when a currency is dropped from the flat fee' do
      rate = create(:commission_rate, store: store, bounds: { 'USD' => { max_amount: 20 } })

      rate.update!(amounts: {})

      expect(rate.max_amount_for('USD')).to eq(20)
    end

    it 'retires a currency dropped from the bounds' do
      rate = create(:commission_rate, store: store,
                    bounds: { 'USD' => { max_amount: 20 }, 'PLN' => { max_amount: 80 } })

      rate.update!(bounds: { 'USD' => { max_amount: 20 } })

      expect(rate.reload.bounds.keys).to eq(['USD'])
    end
  end

  describe 'flat fee amounts' do
    it 'charges what it states for the sale currency' do
      rate = create(:commission_rate, :fixed, store: store, amounts: { 'USD' => 5, 'GBP' => 4 })

      expect(rate.amount_for('USD')).to eq(5)
      expect(rate.amount_for('gbp')).to eq(4)
      expect(rate.amount_for('EUR')).to be_nil
    end

    # A flat fee charging nothing anywhere is skipped for every sale, which
    # reads as a broken rate rather than a disabled one.
    it 'refuses a flat fee that states no amount at all' do
      expect(build(:commission_rate, kind: 'fixed', value: 0)).not_to be_valid
    end

    # Charging the flat amount again per parcel would bill one sale twice, so
    # a marketplace wanting a flat delivery charge states it as its own rate.
    it 'refuses to also charge delivery' do
      rate = build(:commission_rate, :fixed, store: store, include_shipping: true)

      expect(rate).not_to be_valid
      expect(rate.errors[:include_shipping].first).to match(/already charges for the sale/)
    end

    it 'retires a currency dropped from the set' do
      rate = create(:commission_rate, :fixed, store: store, amounts: { 'USD' => 5, 'GBP' => 4 })

      rate.update!(amounts: { 'USD' => 6 })

      expect(rate.reload.amounts).to eq('USD' => 6)
    end
  end

  describe '#matches?' do
    let(:vendor) { create(:vendor, store: store) }
    let(:other_vendor) { create(:vendor, store: store) }
    let(:cameras) { create(:category, store: store) }
    let(:audio) { create(:category, store: store) }
    let(:product) { create(:product, store: store) }
    let(:order) { create(:order, store: store) }
    let(:line_item) { create(:line_item, order: order, variant: product.default_variant, price: 100) }

    def context(categories: [cameras])
      Spree::Commissions::Context.new(
        vendor: vendor, order: order, line_item: line_item, categories: categories
      )
    end

    it 'charges every sale when it names nothing' do
      expect(create(:commission_rate, store: store).matches?(context)).to be true
    end

    it 'matches a rule naming the seller' do
      rate = create(:commission_rate, store: store)
      create(:commission_vendor_rule, commission_rate: rate, vendors: [vendor])

      expect(rate.reload.matches?(context)).to be true
    end

    it 'does not match a rule naming someone else' do
      rate = create(:commission_rate, store: store)
      create(:commission_vendor_rule, commission_rate: rate, vendors: [other_vendor])

      expect(rate.reload.matches?(context)).to be false
    end

    # A rule holding several ids means any of them — the OR lives inside the
    # rule, which is why there is no match-policy setting.
    it 'matches when any id in one rule matches' do
      rate = create(:commission_rate, store: store)
      create(:commission_category_rule, commission_rate: rate, categories: [cameras, audio])

      expect(rate.reload.matches?(context)).to be true
    end

    # ...and every rule has to agree, which is what expresses "this seller, in
    # this category" — the pairing a marketplace actually sells.
    it 'requires every rule to agree' do
      rate = create(:commission_rate, store: store)
      create(:commission_vendor_rule, commission_rate: rate, vendors: [vendor])
      create(:commission_category_rule, commission_rate: rate, categories: [audio])

      expect(rate.reload.matches?(context)).to be false
    end

    it 'matches a seller-and-category pairing when both hold' do
      rate = create(:commission_rate, store: store)
      create(:commission_vendor_rule, commission_rate: rate, vendors: [vendor])
      create(:commission_category_rule, commission_rate: rate, categories: [cameras])

      expect(rate.reload.matches?(context)).to be true
    end

    # A rule left empty by a half-finished form narrows nothing. It must not
    # be read as "every seller" — that would charge sales nobody targeted.
    it 'does not match a rule that names nobody' do
      rate = create(:commission_rate, store: store)
      create(:commission_vendor_rule, commission_rate: rate)

      expect(rate.reload.matches?(context)).to be false
    end

    # The rule kind that could not exist while a rule could only name a record.
    describe 'a value band' do
      it 'matches inside the band' do
        rate = create(:commission_rate, store: store)
        create(:commission_item_total_rule, commission_rate: rate,
                                            preferred_min_amount: 50, preferred_max_amount: 200)

        expect(rate.reload.matches?(context)).to be true
      end

      it 'does not match below it' do
        rate = create(:commission_rate, store: store)
        create(:commission_item_total_rule, commission_rate: rate, preferred_min_amount: 500)

        expect(rate.reload.matches?(context)).to be false
      end

      # The band has to weigh the sale exactly as the fee will. On a
      # tax-inclusive store a 100 item carrying 20 of VAT is worth 80 to the
      # seller, so a band drawn under 100 must admit it — otherwise the fee
      # charges on a figure the band never saw.
      it 'weighs the sale the same way the fee will' do
        line_item.update_columns(included_tax_total: 20)
        rate = create(:commission_rate, store: store)
        create(:commission_item_total_rule, commission_rate: rate, preferred_max_amount: 90)

        expect(rate.reload.matches?(context)).to be true
      end

      # Bounds meet at a number without covering it twice, so two bands can be
      # laid end to end.
      it 'treats the ceiling as exclusive' do
        rate = create(:commission_rate, store: store)
        create(:commission_item_total_rule, commission_rate: rate, preferred_max_amount: 100)

        expect(rate.reload.matches?(context)).to be false
      end
    end
  end

  describe '#rules=' do
    let(:vendor) { create(:vendor, store: store) }
    let(:category) { create(:category, store: store) }

    it 'replaces the rate targeting wholesale' do
      rate = create(:commission_rate, store: store)
      create(:commission_vendor_rule, commission_rate: rate, vendors: [vendor])

      rate.update!(rules: [{ type: 'category_rule', preferences: { category_ids: [category.id] } }])

      expect(rate.reload.commission_rules.map(&:class)).to eq([Spree::CommissionRules::CategoryRule])
      expect(rate.commission_rules.first.preferred_category_ids.map(&:to_s)).to eq([category.id.to_s])
    end

    # One rule per kind, so naming a kind means "this condition should now say
    # that" — the edit lands on the rule already there rather than building a
    # second one beside it.
    it 'edits the rule of a kind the rate already carries' do
      rate = create(:commission_rate, store: store)
      first_vendor = create(:vendor, store: store)
      second_vendor = create(:vendor, store: store)
      rate.update!(rules: [{ type: 'vendor_rule', preferences: { vendor_ids: [first_vendor.id] } }])

      rate.update!(rules: [{ type: 'vendor_rule', preferences: { vendor_ids: [second_vendor.id] } }])

      expect(rate.reload.commission_rules.count).to eq(1)
      expect(rate.commission_rules.first.preferred_vendor_ids.map(&:to_s)).to eq([second_vendor.id.to_s])
    end

    it 'clears the targeting when given nothing' do
      rate = create(:commission_rate, store: store)
      create(:commission_vendor_rule, commission_rate: rate, vendors: [vendor])

      rate.update!(rules: [])

      expect(rate.reload.commission_rules).to be_empty
    end

    # A rule can only be pointed at records of the rate's own store — the
    # preference writer checks as it writes, so the caller is told rather than
    # having the id silently dropped.
    it 'refuses a record belonging to another marketplace' do
      rate = create(:commission_rate, store: store)
      foreign_vendor = create(:vendor, store: create(:store))

      expect {
        rate.update!(rules: [{ type: 'vendor_rule', preferences: { vendor_ids: [foreign_vendor.id] } }])
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'builds rules on a rate that does not exist yet' do
      rate = create(:commission_rate, store: store,
                                      rules: [{ type: 'vendor_rule', preferences: { vendor_ids: [vendor.id] } }])

      expect(rate.reload.commission_rules.map(&:class)).to eq([Spree::CommissionRules::VendorRule])
    end
  end

  describe 'ordering' do
    # The list IS the precedence, so a new rate has to take effect on
    # creation — appending would file it behind the catch-all that already
    # matches everything, leaving it dead on arrival.
    it 'puts a new rate at the top of the list' do
      first = create(:commission_rate, store: store)
      second = create(:commission_rate, store: store)

      expect(described_class.ordered.to_a).to eq([second, first])
    end

    it 'walks the list top-down' do
      bottom = create(:commission_rate, store: store)
      top = create(:commission_rate, store: store)

      expect(described_class.ordered.to_a).to eq([top, bottom])
      # Reloaded: inserting at the top pushes the other row down in the
      # database, which an already-loaded record knows nothing about.
      expect(top.reload.position).to be < bottom.reload.position
    end

    it 'keeps one marketplace positions out of another' do
      other_store = create(:store)
      mine = create(:commission_rate, store: store)
      theirs = create(:commission_rate, store: other_store)

      expect(mine.position).to eq(theirs.position)
      expect(described_class.for_store(store).ordered.to_a).to eq([mine])
    end

    it 'reorders on demand' do
      top = create(:commission_rate, store: store)
      bottom = create(:commission_rate, store: store)

      bottom.move_to_top

      expect(described_class.ordered.to_a).to eq([bottom, top])
    end
  end

  # A rate is paranoid, so `destroy` is a soft delete — and cascading from one
  # would take rules that cannot be restored with it.
  describe 'retiring a rate' do
    let(:vendor) { create(:vendor, store: store) }

    # Retired, not deleted: a commission line is explained by the rule that
    # matched it, so the conditions have to stay readable after the rate stops
    # applying to anything.
    it 'retires its rules with it rather than deleting them' do
      rate = create(:commission_rate, store: store)
      create(:commission_vendor_rule, commission_rate: rate, vendors: [vendor])

      rate.destroy

      expect(Spree::CommissionRule.where(commission_rate_id: rate.id)).to be_empty
      retired = Spree::CommissionRule.with_deleted.find_by(commission_rate_id: rate.id)
      expect(retired.preferred_vendor_ids.map(&:to_s)).to eq([vendor.id.to_s])
    end

    # "Which rate charged this" has to stay answerable after the rate is
    # retired; the rate itself is still there to read through with_deleted.
    it 'leaves the lines it already charged pointing at it' do
      rate = create(:commission_rate, store: store)
      order = create(:order, store: store)
      line = create(:commission_line, order: order, vendor: vendor,
                                      line_item: create(:line_item, order: order), commission_rate: rate)

      rate.destroy

      expect(line.reload.commission_rate_id).to eq(rate.id)
    end
  end

  describe '#global?' do
    it 'is true for a rate that names nothing' do
      expect(create(:commission_rate, store: store)).to be_global
    end

    it 'is false once it carries a rule' do
      rate = create(:commission_rate, store: store)
      create(:commission_vendor_rule, commission_rate: rate, vendors: [create(:vendor, store: store)])

      expect(rate.reload).not_to be_global
    end
  end
end
