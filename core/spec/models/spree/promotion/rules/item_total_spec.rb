require 'spec_helper'

describe Spree::Promotion::Rules::ItemTotal, type: :model do
  let(:rule) { Spree::Promotion::Rules::ItemTotal.new }
  let(:order) { double(:order) }

  before do
    rule.preferred_amount_min = 50
    rule.preferred_amount_max = 60
  end

  context 'preferred operator_min set to gt and preferred operator_max set to lt' do
    before do
      rule.preferred_operator_min = 'gt'
      rule.preferred_operator_max = 'lt'
    end

    context 'and item total is lower than prefered maximum amount' do
      context 'and item total is higher than prefered minimum amount' do
        it 'is eligible' do
          allow(order).to receive_messages item_total: 51
          expect(rule).to be_eligible(order)
        end
      end

      context 'and item total is equal to the prefered minimum amount' do
        before { allow(order).to receive_messages item_total: 50 }

        it 'is not eligible' do
          expect(rule).not_to be_eligible(order)
        end

        it 'set an error message' do
          rule.eligible?(order)
          expect(rule.eligibility_errors.full_messages.first).
            to eq "This coupon code can't be applied to orders less than or equal to $50.00."
        end
      end

      context 'and item total is lower to the prefered minimum amount' do
        before { allow(order).to receive_messages item_total: 49 }

        it 'is not eligible' do
          expect(rule).not_to be_eligible(order)
        end

        it 'set an error message' do
          rule.eligible?(order)
          expect(rule.eligibility_errors.full_messages.first).
            to eq "This coupon code can't be applied to orders less than or equal to $50.00."
        end
      end
    end

    context 'and item total is equal to the prefered maximum amount' do
      before { allow(order).to receive_messages item_total: 60 }

      it 'is not eligible' do
        expect(rule).not_to be_eligible(order)
      end

      it 'set an error message' do
        rule.eligible?(order)
        expect(rule.eligibility_errors.full_messages.first).
          to eq "This coupon code can't be applied to orders higher than or equal to $60.00."
      end
    end

    context 'and item total is higher than the prefered maximum amount' do
      before { allow(order).to receive_messages item_total: 61 }

      it 'is not eligible' do
        expect(rule).not_to be_eligible(order)
      end

      it 'set an error message' do
        rule.eligible?(order)
        expect(rule.eligibility_errors.full_messages.first).
          to eq "This coupon code can't be applied to orders higher than or equal to $60.00."
      end
    end
  end

  context 'preferred operator set to gt and preferred operator_max set to lte' do
    before do
      rule.preferred_operator_min = 'gt'
      rule.preferred_operator_max = 'lte'
    end

    context 'and item total is lower than prefered maximum amount' do
      context 'and item total is higher than prefered minimum amount' do
        it 'is eligible' do
          allow(order).to receive_messages item_total: 51
          expect(rule).to be_eligible(order)
        end
      end

      context 'and item total is equal to the prefered minimum amount' do
        before { allow(order).to receive_messages item_total: 50 }

        it 'is not eligible' do
          expect(rule).not_to be_eligible(order)
        end

        it 'set an error message' do
          rule.eligible?(order)
          expect(rule.eligibility_errors.full_messages.first).
            to eq "This coupon code can't be applied to orders less than or equal to $50.00."
        end
      end

      context 'and item total is lower to the prefered minimum amount' do
        before { allow(order).to receive_messages item_total: 49 }

        it 'is not eligible' do
          expect(rule).not_to be_eligible(order)
        end

        it 'set an error message' do
          rule.eligible?(order)
          expect(rule.eligibility_errors.full_messages.first).
            to eq "This coupon code can't be applied to orders less than or equal to $50.00."
        end
      end
    end

    context 'and item total is equal to the prefered maximum amount' do
      before { allow(order).to receive_messages item_total: 60 }

      it 'is not eligible' do
        expect(rule).to be_eligible(order)
      end
    end

    context 'and item total is higher than the prefered maximum amount' do
      before { allow(order).to receive_messages item_total: 61 }

      it 'is not eligible' do
        expect(rule).not_to be_eligible(order)
      end

      it 'set an error message' do
        rule.eligible?(order)
        expect(rule.eligibility_errors.full_messages.first).
          to eq "This coupon code can't be applied to orders higher than $60.00."
      end
    end
  end

  context 'preferred operator set to gte and preferred operator_max set to lt' do
    before do
      rule.preferred_operator_min = 'gte'
      rule.preferred_operator_max = 'lt'
    end

    context 'and item total is lower than prefered maximum amount' do
      context 'and item total is higher than prefered minimum amount' do
        it 'is eligible' do
          allow(order).to receive_messages item_total: 51
          expect(rule).to be_eligible(order)
        end
      end

      context 'and item total is equal to the prefered minimum amount' do
        before { allow(order).to receive_messages item_total: 50 }

        it 'is not eligible' do
          expect(rule).to be_eligible(order)
        end
      end

      context 'and item total is lower to the prefered minimum amount' do
        before { allow(order).to receive_messages item_total: 49 }

        it 'is not eligible' do
          expect(rule).not_to be_eligible(order)
        end

        it 'set an error message' do
          rule.eligible?(order)
          expect(rule.eligibility_errors.full_messages.first).
            to eq "This coupon code can't be applied to orders less than $50.00."
        end
      end
    end

    context 'and item total is equal to the prefered maximum amount' do
      before { allow(order).to receive_messages item_total: 60 }

      it 'is not eligible' do
        expect(rule).not_to be_eligible(order)
      end

      it 'set an error message' do
        rule.eligible?(order)
        expect(rule.eligibility_errors.full_messages.first).
          to eq "This coupon code can't be applied to orders higher than or equal to $60.00."
      end
    end

    context 'and item total is higher than the prefered maximum amount' do
      before { allow(order).to receive_messages item_total: 61 }

      it 'is not eligible' do
        expect(rule).not_to be_eligible(order)
      end

      it 'set an error message' do
        rule.eligible?(order)
        expect(rule.eligibility_errors.full_messages.first).
          to eq "This coupon code can't be applied to orders higher than or equal to $60.00."
      end
    end
  end

  context 'preferred operator set to gte and preferred operator_max set to lte' do
    before do
      rule.preferred_operator_min = 'gte'
      rule.preferred_operator_max = 'lte'
    end

    context 'and item total is lower than prefered maximum amount' do
      context 'and item total is higher than prefered minimum amount' do
        it 'is eligible' do
          allow(order).to receive_messages item_total: 51
          expect(rule).to be_eligible(order)
        end
      end

      context 'and item total is equal to the prefered minimum amount' do
        before { allow(order).to receive_messages item_total: 50 }

        it 'is not eligible' do
          expect(rule).to be_eligible(order)
        end
      end

      context 'and item total is lower to the prefered minimum amount' do
        before { allow(order).to receive_messages item_total: 49 }

        it 'is not eligible' do
          expect(rule).not_to be_eligible(order)
        end

        it 'set an error message' do
          rule.eligible?(order)
          expect(rule.eligibility_errors.full_messages.first).
            to eq "This coupon code can't be applied to orders less than $50.00."
        end
      end
    end

    context 'and item total is equal to the prefered maximum amount' do
      before { allow(order).to receive_messages item_total: 60 }

      it 'is not eligible' do
        expect(rule).to be_eligible(order)
      end
    end

    context 'and item total is higher than the prefered maximum amount' do
      before { allow(order).to receive_messages item_total: 61 }

      it 'is not eligible' do
        expect(rule).not_to be_eligible(order)
      end

      it 'set an error message' do
        rule.eligible?(order)
        expect(rule.eligibility_errors.full_messages.first).
          to eq "This coupon code can't be applied to orders higher than $60.00."
      end
    end
  end
end
