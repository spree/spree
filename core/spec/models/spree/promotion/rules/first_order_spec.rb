require 'spec_helper'

describe Spree::Promotion::Rules::FirstOrder, type: :model do
  let(:store) { create(:store) }
  let(:rule) { described_class.new }
  let(:user) { create(:user) }

  context 'without a user or email' do
    let(:order) { create(:order, store: store, email: nil, user: nil) }

    it { expect(rule).not_to be_eligible(order) }

    it 'sets an error message' do
      rule.eligible?(order)
      expect(rule.eligibility_errors.full_messages.first).
        to eq 'You need to login or provide your email before applying this coupon code.'
    end
  end

  context 'first order' do
    context 'for a signed user' do
      let(:order) { create(:order, store: store, user: user) }

      context 'with no completed orders' do
        specify do
          allow(order).to receive_messages(user: user)
          expect(rule).to be_eligible(order)
        end

        it 'is eligible when user passed in payload data' do
          expect(rule).to be_eligible(order, user: user)
        end
      end

      context 'with completed orders' do
        let(:order) { create(:completed_order_with_totals, store: store, user: user) }

        it 'is eligible when checked against first completed order' do
          expect(rule).to be_eligible(order)
        end

        context 'with another order' do
          before do
            create(:completed_order_with_totals, user: user, store: store)
          end

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

      let(:order) { create(:order, store: store, email: email, user: nil) }

      context 'with no other orders' do
        it { expect(rule).to be_eligible(order) }
      end

      context 'with another order' do
        before { create(:completed_order_with_totals, email: email, store: store, user: nil) }

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
