require 'spec_helper'

describe Spree::Promotion::Rules::Product do
  let(:rule) { Spree::Promotion::Rules::Product.new }

  context "#eligible?(order)" do
    let(:order) { Spree::Order.new }

    it "should be eligible if there are no products" do
      rule.stub(:eligible_products => [])
      rule.should be_eligible(order)
    end

    before do
      3.times { |i| instance_variable_set("@product#{i}", mock_model(Spree::Product)) }
    end

    context "with 'any' match policy" do
      before { rule.preferred_match_policy = 'any' }

      it "should be eligible if any of the products is in eligible products" do
        order.stub(:products => [@product1, @product2])
        rule.stub(:eligible_products => [@product2, @product3])
        rule.should be_eligible(order)
      end

      context "when none of the products are eligible products" do
        before do
          order.stub(products: [@product1])
          rule.stub(eligible_products: [@product2, @product3])
        end
        it { rule.should_not be_eligible(order) }
        it "sets an error message" do
          rule.eligible?(order)
          expect(rule.eligibility_errors.full_messages.first).
            to eq "You need to add an applicable product before applying this coupon code."
        end
      end
    end

    context "with 'all' match policy" do
      before { rule.preferred_match_policy = 'all' }

      it "should be eligible if all of the eligible products are ordered" do
        order.stub(:products => [@product3, @product2, @product1])
        rule.stub(:eligible_products => [@product2, @product3])
        rule.should be_eligible(order)
      end

      context "when any of the eligible products is not ordered" do
        before do
          order.stub(products: [@product1, @product2])
          rule.stub(eligible_products: [@product1, @product2, @product3])
        end
        it { rule.should_not be_eligible(order) }
        it "sets an error message" do
          rule.eligible?(order)
          expect(rule.eligibility_errors.full_messages.first).
            to eq "This coupon code can't be applied because you don't have all of the necessary products in your cart."
        end
      end
    end

    context "with 'none' match policy" do
      before { rule.preferred_match_policy = 'none' }

      it "should be eligible if none of the order's products are in eligible products" do
        order.stub(:products => [@product1])
        rule.stub(:eligible_products => [@product2, @product3])
        rule.should be_eligible(order)
      end

      context "when any of the order's products are in eligible products" do
        before do
          order.stub(products: [@product1, @product2])
          rule.stub(eligible_products: [@product2, @product3])
        end
        it { rule.should_not be_eligible(order) }
        it "sets an error message" do
          rule.eligible?(order)
          expect(rule.eligibility_errors.full_messages.first).
            to eq "Your cart contains a product that prevents this coupon code from being applied."
        end
      end
    end
  end
end
