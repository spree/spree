require 'spec_helper'

describe Spree::PriceRules::CustomerGroupRule, type: :model do
  let(:store) { @default_store }
  let(:price_list) { create(:price_list, store: store) }
  let(:rule) { create(:customer_group_price_rule, price_list: price_list) }
  let(:customer_group) { create(:customer_group, store: store) }
  let(:other_customer_group) { create(:customer_group, store: store) }
  let(:user) { create(:user) }
  let(:variant) { create(:variant) }

  describe '#applicable?' do
    context 'when customer_group_ids preference is empty' do
      before { rule.preferred_customer_group_ids = [] }

      it 'returns true when user is present' do
        context = Spree::Pricing::Context.new(variant: variant, currency: 'USD', user: user)
        expect(rule.applicable?(context)).to be true
      end

      it 'returns false when user is not present' do
        context = Spree::Pricing::Context.new(variant: variant, currency: 'USD')
        expect(rule.applicable?(context)).to be false
      end
    end

    context 'when customer_group_ids preference is set' do
      before { rule.preferred_customer_group_ids = [customer_group.id] }

      it 'returns true when context user is in the customer group' do
        customer_group.add_customers([user.id])
        context = Spree::Pricing::Context.new(variant: variant, currency: 'USD', user: user)
        expect(rule.applicable?(context)).to be true
      end

      it 'returns false when context user is not in the customer group' do
        other_customer_group.add_customers([user.id])
        context = Spree::Pricing::Context.new(variant: variant, currency: 'USD', user: user)
        expect(rule.applicable?(context)).to be false
      end

      it 'returns false when context has no user' do
        context = Spree::Pricing::Context.new(variant: variant, currency: 'USD')
        expect(rule.applicable?(context)).to be false
      end
    end

    context 'when customer_group_ids preference contains strings' do
      before { rule.preferred_customer_group_ids = [customer_group.id.to_s] }

      it 'returns true when context user is in the customer group' do
        customer_group.add_customers([user.id])
        context = Spree::Pricing::Context.new(variant: variant, currency: 'USD', user: user)
        expect(rule.applicable?(context)).to be true
      end
    end

    context 'with multiple customer groups configured' do
      before { rule.preferred_customer_group_ids = [customer_group.id, other_customer_group.id] }

      it 'returns true when context user is in any of the customer groups' do
        other_customer_group.add_customers([user.id])
        context = Spree::Pricing::Context.new(variant: variant, currency: 'USD', user: user)
        expect(rule.applicable?(context)).to be true
      end

      it 'returns false when context user is not in any of the customer groups' do
        context = Spree::Pricing::Context.new(variant: variant, currency: 'USD', user: user)
        expect(rule.applicable?(context)).to be false
      end
    end
  end

  describe '.description' do
    it 'returns the translated description' do
      expect(Spree::PriceRules::CustomerGroupRule.description).to eq(Spree.t('price_rules.customer_group_rule.description'))
    end
  end

  describe '#preferred_customer_group_ids=' do
    it 'decodes prefixed customer group IDs to raw IDs' do
      rule.preferred_customer_group_ids = [customer_group.prefixed_id]
      expect(rule.preferred_customer_group_ids).to eq([customer_group.id.to_s])
    end

    it 'accepts a mix of prefixed and raw IDs' do
      rule.preferred_customer_group_ids = [customer_group.prefixed_id, other_customer_group.id.to_s]
      expect(rule.preferred_customer_group_ids).to contain_exactly(customer_group.id.to_s, other_customer_group.id.to_s)
    end
  end

  describe '#customer_groups' do
    it 'returns the customer groups matching the preferred IDs' do
      rule.preferred_customer_group_ids = [customer_group.id, other_customer_group.id]
      expect(rule.customer_groups).to contain_exactly(customer_group, other_customer_group)
    end

    it 'returns an empty relation when no groups are set' do
      rule.preferred_customer_group_ids = []
      expect(rule.customer_groups).to be_empty
    end
  end
end
