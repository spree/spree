require 'spec_helper'

describe Spree::Promotion::Rules::User, type: :model do
  let(:rule) { Spree::Promotion::Rules::User.new }
  let(:random_user) { create :user }
  let(:user_placing_order) { create :user }

  describe '#eligible?' do
    let(:order) { Spree::Order.new }

    it 'is not eligible if users are not provided' do
      expect(rule).not_to be_eligible(order)
    end

    context 'when users include user placing the order' do
      let(:users) { [user_placing_order, random_user] }

      it 'is eligible if users include user placing the order' do
        allow(rule).to receive_messages(users: users)
        allow(order).to receive_messages(user: user_placing_order)

        expect(rule).to be_eligible(order)
      end
    end

    context 'when users does not include user placing the order' do
      let(:users) { create_list(:user, 2) }

      it 'is not eligible if user placing the order is not listed' do
        allow(rule).to receive_messages(users: users)
        allow(order).to receive_messages(user: user_placing_order)

        expect(rule).not_to be_eligible(order)
      end
    end

    # Regression test for #3885
    it 'can assign to user_ids' do
      expect { rule.user_ids = "#{random_user.id}, #{user_placing_order.id}" }.not_to raise_error
    end
  end
end
