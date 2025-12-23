require 'spec_helper'

describe Spree::Promotion::Rules::User, type: :model do
  let(:rule) { Spree::Promotion::Rules::User.new }
  let(:random_user) { create :user }
  let(:user_placing_order) { create :user }

  describe '#eligible?' do
    let(:order) { build(:order, user: user_placing_order) }

    it 'is not eligible if users are not provided' do
      expect(rule).not_to be_eligible(order)
    end

    context 'when users include user placing the order' do
      let(:users) { [user_placing_order, random_user] }

      it 'is eligible if users include user placing the order' do
        allow(rule).to receive_messages(eligible_user_ids: users.map(&:id))

        expect(rule).to be_eligible(order)
      end
    end

    context 'when users does not include user placing the order' do
      let(:users) { create_list(:user, 2) }

      it 'is not eligible if user placing the order is not listed' do
        allow(rule).to receive_messages(eligible_user_ids: users.map(&:id))

        expect(rule).not_to be_eligible(order)
      end
    end

    # Regression test for #3885
    it 'can assign to user_ids' do
      expect { rule.user_ids = "#{random_user.id}, #{user_placing_order.id}" }.not_to raise_error
    end
  end

  describe '#add_users' do
    let(:promotion) { create(:promotion) }
    let(:rule) { create(:promotion_rule_user, promotion: promotion) }

    it 'adds users to the promotion rule' do
      rule.user_ids_to_add = [random_user.id, user_placing_order.id]
      rule.save!
      expect(rule.users).to include(random_user, user_placing_order)
    end

    it 'removes users from the promotion rule' do
      rule.user_ids_to_add = [random_user.id, user_placing_order.id]
      rule.save!
      rule.user_ids_to_add = []
      rule.save!
      expect(rule.users).to be_empty
    end

    it 'does not remove the users when nil is passed' do
      rule.user_ids_to_add = [random_user.id, user_placing_order.id]
      rule.save!
      rule.user_ids_to_add = nil
      rule.save!
      expect(rule.users).to include(random_user, user_placing_order)
    end
  end
end
