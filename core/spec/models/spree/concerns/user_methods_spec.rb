require 'spec_helper'

describe Spree::UserMethods do
  let(:test_user) { create :user }
  let(:current_store) { create :store }

  describe '#has_spree_role?' do
    subject { test_user.has_spree_role? name }

    let(:role) { Spree::Role.create(name: name) }
    let(:name) { 'test' }

    context 'with a role' do
      before { test_user.spree_roles << role }
      it { is_expected.to be_truthy }
    end

    context 'without a role' do
      it { is_expected.to be_falsy }
    end
  end

  describe '#last_incomplete_spree_order' do
    subject { test_user.last_incomplete_spree_order(current_store) }

    context 'with an incomplete order' do
      let(:last_incomplete_order) { create :order, user: test_user, store: current_store }

      before do
        create(:order, user: test_user, created_at: 1.day.ago, store: current_store)
        create(:order, user: create(:user), store: current_store)
        last_incomplete_order
      end

      it { is_expected.to eq last_incomplete_order }
    end

    context 'without an incomplete order' do
      it { is_expected.to be_nil }
    end
  end

  context '#check_completed_orders' do
    let(:possible_promotion) { create(:promotion, advertise: true, starts_at: 1.day.ago) }

    context 'rstrict t delete dependent destroyed' do
      before do
        test_user.promotion_rules.create!(promotion: possible_promotion)
        create(:order, user: test_user, completed_at: Time.current)
      end

      it 'does not destroy dependent destroy items' do
        expect { test_user.destroy }.to raise_error(Spree::Core::DestroyWithOrdersError)
        expect(test_user.promotion_rule_users.any?).to be(true)
      end
    end

    context 'allow to destroy dependent destroy' do
      before do
        test_user.promotion_rules.create!(promotion: possible_promotion)
        create(:order, user: test_user, created_at: 1.day.ago)
        test_user.destroy
      end

      it 'does not destroy dependent destroy items' do
        expect(test_user.promotion_rule_users.any?).to be(false)
      end
    end
  end

  context 'when user destroyed with approved orders' do
    let(:order) { create(:order, approver_id: test_user.id, created_at: 1.day.ago) }

    it 'nullifies all approver ids' do
      expect(test_user).to receive(:nullify_approver_id_in_approved_orders)
      test_user.destroy
    end
  end
end
