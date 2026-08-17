require 'spec_helper'

describe Spree::Promotion::Rules::CustomerGroup, type: :model do
  let(:store) { @default_store }
  let(:promotion) { create(:promotion, store: store) }
  # Attached to its promotion, because the rule resolves group ids through
  # that promotion's store.
  let(:rule) { described_class.new(promotion: promotion) }
  let(:customer_group) { create(:customer_group, store: store) }
  let(:other_customer_group) { create(:customer_group, store: store) }
  let(:user) { create(:user) }

  describe '#applicable?' do
    it 'returns true for orders' do
      order = build(:order)
      expect(rule.applicable?(order)).to be true
    end

    it 'returns false for non-orders' do
      expect(rule.applicable?('not an order')).to be false
    end
  end

  describe '#eligible?' do
    let(:order) { build(:order, customer: user) }

    context 'when no customer groups are configured' do
      before { rule.preferred_customer_group_ids = [] }

      it 'is not eligible' do
        expect(rule).not_to be_eligible(order)
      end
    end

    context 'when order has no user' do
      let(:order) { build(:order, customer: nil) }

      before { rule.preferred_customer_group_ids = [customer_group.id] }

      it 'is not eligible' do
        expect(rule).not_to be_eligible(order)
      end
    end

    context 'when user is in the customer group' do
      before do
        customer_group.add_customers([user.id])
        rule.preferred_customer_group_ids = [customer_group.id]
      end

      it 'is eligible' do
        expect(rule).to be_eligible(order)
      end
    end

    context 'when user is not in any configured customer group' do
      before do
        other_customer_group.add_customers([user.id])
        rule.preferred_customer_group_ids = [customer_group.id]
      end

      it 'is not eligible' do
        expect(rule).not_to be_eligible(order)
      end
    end

    context 'when user is in one of multiple configured customer groups' do
      before do
        customer_group.add_customers([user.id])
        rule.preferred_customer_group_ids = [customer_group.id, other_customer_group.id]
      end

      it 'is eligible' do
        expect(rule).to be_eligible(order)
      end
    end

    context 'when customer_group_ids contains strings' do
      before do
        customer_group.add_customers([user.id])
        rule.preferred_customer_group_ids = [customer_group.id.to_s]
      end

      it 'is eligible' do
        expect(rule).to be_eligible(order)
      end
    end
  end

  # Groups are store-owned, so a promotion must not target an audience
  # belonging to another store.
  context 'when given a customer group from another store' do
    let(:foreign_group) { create(:customer_group, store: create(:store)) }

    it 'rejects the foreign ID' do
      expect { rule.preferred_customer_group_ids = [foreign_group.prefixed_id] }.
        to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
