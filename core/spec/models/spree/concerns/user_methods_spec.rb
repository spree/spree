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

  describe '#payment_sources' do
    subject { test_user.payment_sources }

    let(:next_year) { DateTime.now.year + 1 }
    let(:previous_year) { DateTime.now.year - 1 }
    let(:gateway_customer_profile_id) { 'SDS-4231' }
    let(:other_user) { create :user }
    let(:active_payment_method) { create(:credit_card_payment_method, active: true) }
    let(:inactive_payment_method) { create(:credit_card_payment_method, active: false) }

    let!(:valid_credit_card) do
      create(:credit_card, user: test_user, gateway_customer_profile_id: gateway_customer_profile_id, year: next_year, payment_method: active_payment_method)
    end
    let!(:other_user_credit_card) { create(:credit_card, user: other_user, gateway_customer_profile_id: gateway_customer_profile_id, year: next_year) }
    let!(:blank_payment_profile_credit_card) { create(:credit_card, user: test_user, gateway_customer_profile_id: nil, year: next_year) }
    let!(:outdated_credit_card) { create(:credit_card, user: test_user, gateway_customer_profile_id: gateway_customer_profile_id, year: previous_year) }
    let!(:credit_card_with_inactive_payment_method) do
      create(:credit_card, user: test_user, gateway_customer_profile_id: gateway_customer_profile_id, year: next_year, payment_method: inactive_payment_method)
    end

    it 'includes only not expired credit cards with payment profile that belong to subject user' do
      expect(subject).to include(valid_credit_card)
    end

    it 'does not include credit cards that belong to other user' do
      expect(subject).not_to include(other_user_credit_card)
    end

    it 'does not include credit cards without payment profile' do
      expect(subject).not_to include(blank_payment_profile_credit_card)
    end

    it 'does not include outdated credit cards' do
      expect(subject).not_to include(outdated_credit_card)
    end

    it 'does not include credit cards with inactive payment method' do
      expect(subject).not_to include(credit_card_with_inactive_payment_method)
    end
  end
end
