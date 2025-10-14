require 'spec_helper'

describe Spree::UserMethods do
  let(:test_user) { create :user }
  let!(:another_user) { create(:user) }
  let(:current_store) { @default_store }

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

    context 'with incomplete canceled order' do
      let(:canceled_order) { create(:order, user: test_user, created_at: 1.day.ago, store: current_store, state: 'canceled') }

      it { is_expected.to be_nil }
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

  describe '#scramble_email_and_names' do
    it 'scramble email and names' do
      expect { test_user.send(:scramble_email_and_names) }.to change(test_user, :email).and change(test_user, :first_name).and change(test_user, :last_name)
      expect(test_user.login).to eq(test_user.email)
      expect(test_user.first_name).to eq('Deleted')
      expect(test_user.last_name).to eq('User')
    end
  end

  describe '#invited_by' do
    it 'returns the user who invited the current user' do
      invitation = create(:invitation, invitee: test_user)
      expect(test_user.invited_by).to eq(invitation.inviter)
    end
  end

  describe '.multi_search' do
    let!(:user_1) { create(:user, email: 'john.doe@example.com', first_name: 'John', last_name: 'Doe') }
    let!(:user_2) { create(:user, email: 'jane.doe@example.com', first_name: 'Jane', last_name: 'Gone') }
    let!(:user_3) { create(:user, email: 'mary.moe@example.com', first_name: 'Mary', last_name: 'Moe') }
    let!(:user_4) { create(:user, email: 'john_doe@example.com', first_name: 'Ayn', last_name: 'Rand') }
    let!(:user_5) { create(:user, email: 'johndoe@example.com', first_name: 'John', last_name: 'Doe') }

    it 'returns users based on an email' do
      expect(Spree.user_class.multi_search('john.doe@example.com')).to eq([user_1])
      expect(Spree.user_class.multi_search('jane.doe@example.com')).to eq([user_2])
      expect(Spree.user_class.multi_search('john_doe@example.com')).to eq([user_4])
      expect(Spree.user_class.multi_search('johndoe@example.com')).to eq([user_5])
      expect(Spree.user_class.multi_search('mary.moe@')).to eq([])
    end

    it 'returns users based on the first name' do
      expect(Spree.user_class.multi_search('joh')).to eq([user_1, user_5])
      expect(Spree.user_class.multi_search('jan')).to eq([user_2])
      expect(Spree.user_class.multi_search('greg')).to eq([])
    end

    it 'returns users based on the last name' do
      expect(Spree.user_class.multi_search('do')).to eq([user_1, user_5])
      expect(Spree.user_class.multi_search('moe')).to eq([user_3])
      expect(Spree.user_class.multi_search('smith')).to eq([])
    end

    it 'returns users based on the full name' do
      expect(Spree.user_class.multi_search('joh do')).to eq([user_1, user_5])
      expect(Spree.user_class.multi_search('ane gon')).to eq([user_2])
      expect(Spree.user_class.multi_search('mary moe')).to eq([user_3])
      expect(Spree.user_class.multi_search('jane moe')).to eq([user_2, user_3])
      expect(Spree.user_class.multi_search('greg smith')).to eq([])
    end
  end

  describe '#can_be_deleted?' do
    subject { test_user.can_be_deleted? }

    context 'when user has a role on current store' do
      let!(:role) { create(:role, name: 'test') }

      it 'returns true if another user also has a role on the store' do
        test_user.add_role(role.name, current_store)
        other_user = create(:user)
        other_user.add_role(role.name, current_store)

        expect(subject).to be(true)
      end

      it 'returns false if user is the last with a role on the store' do
        current_store.role_users.destroy_all
        test_user.add_role(role.name, current_store)

        expect(subject).to be(false)
      end
    end

    context 'when user has no role on current store' do
      it 'returns true if user has no completed orders' do
        expect(subject).to be(true)
      end

      it 'returns false if user has completed orders' do
        create(:order, user: test_user, completed_at: Time.current)

        expect(subject).to be(false)
      end
    end
  end
end
