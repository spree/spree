require 'spec_helper'

describe Spree::Promotion::Rules::FirstOrder, type: :model do
  let(:rule) { Spree::Promotion::Rules::FirstOrder.new }
  let(:order) { mock_model(Spree::Order, user: nil, email: nil) }
  let(:user) { mock_model(Spree::LegacyUser) }

  context 'without a user or email' do
    it { expect(rule).not_to be_eligible(order) }
    it 'sets an error message' do
      rule.eligible?(order)
      expect(rule.eligibility_errors.full_messages.first).
        to eq 'You need to login or provide your email before applying this coupon code.'
    end
  end

  context 'first order' do
    context 'for a signed user' do
      context 'with no completed orders' do
        before do
          allow(user).to receive_message_chain(:orders, complete: [])
        end

        specify do
          allow(order).to receive_messages(user: user)
          expect(rule).to be_eligible(order)
        end

        it 'is eligible when user passed in payload data' do
          expect(rule).to be_eligible(order, user: user)
        end
      end

      context 'with completed orders' do
        before do
          allow(order).to receive_messages(user: user)
        end

        it 'is eligible when checked against first completed order' do
          allow(user).to receive_message_chain(:orders, complete: [order])
          expect(rule).to be_eligible(order)
        end

        context 'with another order' do
          before { allow(user).to receive_message_chain(:orders, complete: [mock_model(Spree::Order)]) }

          it { expect(rule).not_to be_eligible(order) }
          it 'sets an error message' do
            rule.eligible?(order)
            expect(rule.eligibility_errors.full_messages.first).
              to eq 'This coupon code can only be applied to your first order.'
          end
        end
      end
    end

    context 'for a guest user' do
      let(:email) { 'user@spreecommerce.org' }

      before { allow(order).to receive_messages email: 'user@spreecommerce.org' }

      context 'with no other orders' do
        it { expect(rule).to be_eligible(order) }
      end

      context 'with another order' do
        before { allow(rule).to receive_messages(orders_by_email: [mock_model(Spree::Order)]) }

        it { expect(rule).not_to be_eligible(order) }
        it 'sets an error message' do
          rule.eligible?(order)
          expect(rule.eligibility_errors.full_messages.first).
            to eq 'This coupon code can only be applied to your first order.'
        end
      end
    end
  end
end
