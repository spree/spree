require 'spec_helper'

describe Spree::Promotion::Rules::ItemQuantity, :type => :model do
  let(:rule) { Spree::Promotion::Rules::ItemQuantity.new }
  let(:order) { double(:order) }

  before { rule.preferred_quantity_min = 4 }
  before { rule.preferred_quantity_max = 10 }

  context "preferred operator_min set to gt and preferred operator_max set to lt" do
    before do
      rule.preferred_operator_min = 'gt'
      rule.preferred_operator_max = 'lt'
    end

    context "and item quantity is lower than prefered maximum quantity" do

      context "and item quantity is higher than prefered minimum quantity" do
        it "should be eligible" do
          allow(order).to receive_messages quantity: 5
          expect(rule).to be_eligible(order)
        end
      end

      context "and item number is equal to the prefered minimum number" do
        before { allow(order).to receive_messages quantity: 4 }

        it "should not be eligible" do
          expect(rule).to_not be_eligible(order)
        end

        it "set an error message" do
          rule.eligible?(order)
          expect(rule.eligibility_errors.full_messages.first).
            to eq "This coupon code can't be applied to orders with items quantity less than or equal to 4."
        end
      end

      context "and quantity is lower to the prefered minimum quantity" do
        before { allow(order).to receive_messages quantity: 3 }

        it "should not be eligible" do
          expect(rule).to_not be_eligible(order)
        end

        it "set an error message" do
          rule.eligible?(order)
          expect(rule.eligibility_errors.full_messages.first).
            to eq "This coupon code can't be applied to orders with items quantity less than or equal to 4."
        end
      end
    end

    context "and quantity is equal to the prefered maximum quantity" do
      before { allow(order).to receive_messages quantity: 10 }

      it "should not be eligible" do
        expect(rule).to_not be_eligible(order)
      end

      it "set an error message" do
        rule.eligible?(order)
        expect(rule.eligibility_errors.full_messages.first).
          to eq "This coupon code can't be applied to orders with items quantity higher than 10."
      end
    end

    context "and quantity is higher than the prefered maximum quantity" do
      before { allow(order).to receive_messages quantity: 15 }

      it "should not be eligible" do
        expect(rule).to_not be_eligible(order)
      end

      it "set an error message" do
        rule.eligible?(order)
        expect(rule.eligibility_errors.full_messages.first).
          to eq "This coupon code can't be applied to orders with items quantity higher than 10."
      end
    end

  end

  context "preferred operator set to gt and preferred operator_max set to lte" do
    before do
      rule.preferred_operator_min = 'gt'
      rule.preferred_operator_max = 'lte'
    end

    context "and quantity is lower than prefered maximum quantity" do

      context "and quantity is higher than prefered minimum quantity" do
        it "should be eligible" do
          allow(order).to receive_messages quantity: 6
          expect(rule).to be_eligible(order)
        end
      end

      context "and quantity is equal to the prefered minimum quantity" do

        before { allow(order).to receive_messages quantity: 4 }

        it "should not be eligible" do
          expect(rule).to_not be_eligible(order)
        end

        it "set an error message" do
          rule.eligible?(order)
          expect(rule.eligibility_errors.full_messages.first).
            to eq "This coupon code can't be applied to orders with items quantity less than or equal to 4."
        end
      end

      context "and quantity is lower to the prefered minimum quantity" do
        before { allow(order).to receive_messages quantity: 2 }

        it "should not be eligible" do
          expect(rule).to_not be_eligible(order)
        end

        it "set an error message" do
          rule.eligible?(order)
          expect(rule.eligibility_errors.full_messages.first).
            to eq "This coupon code can't be applied to orders with items quantity less than or equal to 4."
        end
      end
    end

    context "and quantity is equal to the prefered maximum quantity" do
      before { allow(order).to receive_messages quantity: 10 }

      it "should be eligible" do
        expect(rule).to be_eligible(order)
      end
    end

    context "and quantity is higher than the prefered maximum quantity" do
      before { allow(order).to receive_messages quantity: 15 }

      it "should not be eligible" do
        expect(rule).to_not be_eligible(order)
      end

      it "set an error message" do
        rule.eligible?(order)
        expect(rule.eligibility_errors.full_messages.first).
          to eq "This coupon code can't be applied to orders with items quantity higher than 10."
      end
    end
  end

  context "preferred operator set to gte and preferred operator_max set to lt" do
    before do
      rule.preferred_operator_min = 'gte'
      rule.preferred_operator_max = 'lt'
    end

    context "and quantity is lower than prefered maximum quantity" do

      context "and quantity is higher than prefered minimum quantity" do
        it "should be eligible" do
          allow(order).to receive_messages quantity: 6
          expect(rule).to be_eligible(order)
        end
      end

      context "and quantity is equal to the prefered minimum quantity" do

        before { allow(order).to receive_messages quantity: 4 }

        it "should be eligible" do
          expect(rule).to be_eligible(order)
        end
      end

      context "and quantity is lower to the prefered minimum quantity" do
        before { allow(order).to receive_messages quantity: 3 }

        it "should not be eligible" do
          expect(rule).to_not be_eligible(order)
        end

        it "set an error message" do
          rule.eligible?(order)
          expect(rule.eligibility_errors.full_messages.first).
            to eq "This coupon code can't be applied to orders with less than 4 items."
        end
      end
    end

    context "and quantity is equal to the prefered maximum quantity" do
      before { allow(order).to receive_messages quantity: 10 }

      it "should not be eligible" do
        expect(rule).to_not be_eligible(order)
      end

      it "set an error message" do
        rule.eligible?(order)
        expect(rule.eligibility_errors.full_messages.first).
          to eq "This coupon code can't be applied to orders with items quantity higher than 10."
      end
    end

    context "and quantity is higher than the prefered maximum quantity" do
      before { allow(order).to receive_messages quantity: 15 }

      it "should not be eligible" do
        expect(rule).to_not be_eligible(order)
      end

      it "set an error message" do
        rule.eligible?(order)
        expect(rule.eligibility_errors.full_messages.first).
          to eq "This coupon code can't be applied to orders with items quantity higher than 10."
      end
    end

  end

  context "preferred operator set to gte and preferred operator_max set to lte" do
    before do
      rule.preferred_operator_min = 'gte'
      rule.preferred_operator_max = 'lte'
    end

    context "and quantity is lower than prefered maximum quantity" do
      context "and quantity is higher than prefered minimum quantity" do
        it "should be eligible" do
          allow(order).to receive_messages quantity: 6
          expect(rule).to be_eligible(order)
        end
      end

      context "and quantity is equal to the prefered minimum quantity" do

        before { allow(order).to receive_messages quantity: 4 }

        it "should be eligible" do
          expect(rule).to be_eligible(order)
        end
      end

      context "and quantity is lower to the prefered minimum quantity" do
        before { allow(order).to receive_messages quantity: 2 }

        it "should not be eligible" do
          expect(rule).to_not be_eligible(order)
        end

        it "set an error message" do
          rule.eligible?(order)
          expect(rule.eligibility_errors.full_messages.first).
            to eq "This coupon code can't be applied to orders with less than 4 items."
        end
      end
    end

    context "and quantity is equal to the prefered maximum quantity" do
      before { allow(order).to receive_messages quantity: 10 }

      it "should be eligible" do
        expect(rule).to be_eligible(order)
      end
    end

    context "and quantity is higher than the prefered maximum quantity" do
      before { allow(order).to receive_messages quantity: 15 }

      it "should not be eligible" do
        expect(rule).to_not be_eligible(order)
      end

      it "set an error message" do
        rule.eligible?(order)
        expect(rule.eligibility_errors.full_messages.first).
          to eq "This coupon code can't be applied to orders with items quantity higher than 10."
      end
    end
  end
end
