require 'spec_helper'

RSpec.describe Spree::CommissionRate, type: :model do
  let(:store) { @default_store }

  describe 'validations' do
    it 'requires a currency on a fixed rate but not on a percentage' do
      expect(build(:commission_rate, kind: 'fixed', currency: nil)).not_to be_valid
      expect(build(:commission_rate, kind: 'percentage', currency: nil)).to be_valid
    end

    it 'rejects a cap below the floor' do
      rate = build(:commission_rate, min_amount: 10, max_amount: 5)

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

  describe '#matches_subjects?' do
    let(:vendor) { create(:vendor, store: store) }
    let(:other_vendor) { create(:vendor, store: store) }
    let(:cameras) { create(:category) }
    let(:audio) { create(:category) }
    let(:product) { create(:product, store: store) }

    let(:subjects) do
      { 'Spree::Vendor' => [vendor], 'Spree::Category' => [cameras], 'Spree::Product' => [product] }
    end

    it 'matches everything when it carries no rules' do
      expect(create(:commission_rate, store: store).matches_subjects?(subjects)).to be true
    end

    it 'matches on a single dimension' do
      rate = create(:commission_rate, store: store)
      create(:commission_rule, commission_rate: rate, subject: vendor)

      expect(rate.reload.matches_subjects?(subjects)).to be true
    end

    it 'does not match a rule naming someone else' do
      rate = create(:commission_rate, store: store)
      create(:commission_rule, commission_rate: rate, subject: other_vendor)

      expect(rate.reload.matches_subjects?(subjects)).to be false
    end

    # The dimension-grouped rule: OR inside one subject type.
    it 'matches when any rule of a dimension matches' do
      rate = create(:commission_rate, store: store)
      create(:commission_rule, commission_rate: rate, subject: cameras)
      create(:commission_rule, commission_rate: rate, subject: audio)

      expect(rate.reload.matches_subjects?(subjects)).to be true
    end

    # ...and AND across them, which is what expresses "this seller, in this
    # category" — the pairing a marketplace actually sells.
    it 'requires every dimension it names to match' do
      rate = create(:commission_rate, store: store)
      create(:commission_rule, commission_rate: rate, subject: vendor)
      create(:commission_rule, commission_rate: rate, subject: audio)

      expect(rate.reload.matches_subjects?(subjects)).to be false
    end

    it 'matches a seller-and-category pairing when both hold' do
      rate = create(:commission_rate, store: store)
      create(:commission_rule, commission_rate: rate, subject: vendor)
      create(:commission_rule, commission_rate: rate, subject: cameras)

      expect(rate.reload.matches_subjects?(subjects)).to be true
    end

    it 'ignores a dimension the rate says nothing about' do
      rate = create(:commission_rate, store: store)
      create(:commission_rule, commission_rate: rate, subject: vendor)

      expect(rate.reload.matches_subjects?(subjects.except('Spree::Category'))).to be true
    end

    it 'treats a global rule as no constraint' do
      rate = create(:commission_rate, store: store)
      create(:commission_rule, commission_rate: rate, subject: nil)

      expect(rate.reload.matches_subjects?(subjects)).to be true
    end
  end

  describe '#rules=' do
    let(:vendor) { create(:vendor, store: store) }
    let(:category) { create(:category) }

    it 'replaces the rate targeting wholesale' do
      rate = create(:commission_rate, store: store)
      create(:commission_rule, commission_rate: rate, subject: vendor)

      rate.update!(rules: [{ subject_type: 'Spree::Category', subject_id: category.id }])

      expect(rate.reload.commission_rules.map(&:subject)).to eq([category])
    end

    it 'clears the targeting when given nothing' do
      rate = create(:commission_rate, store: store)
      create(:commission_rule, commission_rate: rate, subject: vendor)

      rate.update!(rules: [])

      expect(rate.reload.commission_rules).to be_empty
    end
  end

  describe '.by_priority' do
    it 'walks from the highest priority down' do
      low = create(:commission_rate, store: store, priority: 1)
      high = create(:commission_rate, store: store, priority: 10)

      expect(described_class.by_priority.to_a).to eq([high, low])
    end
  end
end
