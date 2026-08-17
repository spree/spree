require 'spec_helper'

RSpec.describe Spree::CommissionRate, type: :model do
  let(:store) { @default_store }

  describe 'validations' do
    it 'requires a currency on a fixed rate but not on a plain percentage' do
      expect(build(:commission_rate, kind: 'fixed', currency: nil)).not_to be_valid
      expect(build(:commission_rate, kind: 'percentage', currency: nil)).to be_valid
    end

    # A floor or a cap is an amount, so a percentage carrying one is no longer
    # free to travel — "at least 5" means 5 of something.
    it 'requires a currency once a percentage carries a floor or a cap' do
      expect(build(:commission_rate, kind: 'percentage', min_amount: 5, currency: nil)).not_to be_valid
      expect(build(:commission_rate, kind: 'percentage', max_amount: 50, currency: nil)).not_to be_valid
      expect(build(:commission_rate, kind: 'percentage', min_amount: 5, currency: 'USD')).to be_valid
    end

    # The override takes precedence over the store default, so it needs the
    # same bound: it is multiplied straight into what a seller is charged.
    it 'refuses a commission tax rate above one' do
      expect(build(:commission_rate, commission_tax_rate: 21)).not_to be_valid
      expect(build(:commission_rate, commission_tax_rate: 0.21)).to be_valid
    end

    it 'rejects a cap below the floor' do
      rate = build(:commission_rate, min_amount: 10, max_amount: 5, currency: 'USD')

      expect(rate).not_to be_valid
      expect(rate.errors[:max_amount]).to be_present
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

    it 'holds a fixed rate to its own currency' do
      rate = build(:commission_rate, :fixed, currency: 'EUR')

      expect(rate.applies_to_currency?('EUR')).to be true
      expect(rate.applies_to_currency?('usd')).to be false
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

    it 'keeps its rules, so restoring it does not make it charge everything' do
      rate = create(:commission_rate, store: store)
      create(:commission_vendor_rule, commission_rate: rate, vendors: [vendor])

      rate.destroy
      rate.restore

      expect(rate.reload.commission_rules.count).to eq(1)
      expect(rate).not_to be_global
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
