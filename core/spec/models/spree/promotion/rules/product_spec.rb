require 'spec_helper'

describe Spree::Promotion::Rules::Product, :type => :model do
  let(:rule) { Spree::Promotion::Rules::Product.new }

  context "#eligible?(order)" do
    let(:order) { Spree::Order.new }

    it "should be eligible if there are no products" do
      allow(rule).to receive_messages(:eligible_products => [])
      expect(rule).to be_eligible(order)
    end

    before do
      3.times { |i| instance_variable_set("@product#{i}", mock_model(Spree::Product)) }
    end

    context "with 'any' match policy" do
      before { rule.preferred_match_policy = 'any' }

      it "should be eligible if any of the products is in eligible products" do
        allow(order).to receive_messages(:products => [@product1, @product2])
        allow(rule).to receive_messages(:eligible_products => [@product2, @product3])
        expect(rule).to be_eligible(order)
      end

      it "should not be eligible if none of the products is in eligible products" do
        allow(order).to receive_messages(:products => [@product1])
        allow(rule).to receive_messages(:eligible_products => [@product2, @product3])
        expect(rule).not_to be_eligible(order)
      end
    end

    context "with 'all' match policy" do
      before { rule.preferred_match_policy = 'all' }

      it "should be eligible if all of the eligible products are ordered" do
        allow(order).to receive_messages(:products => [@product3, @product2, @product1])
        allow(rule).to receive_messages(:eligible_products => [@product2, @product3])
        expect(rule).to be_eligible(order)
      end

      it "should not be eligible if any of the eligible products is not ordered" do
        allow(order).to receive_messages(:products => [@product1, @product2])
        allow(rule).to receive_messages(:eligible_products => [@product1, @product2, @product3])
        expect(rule).not_to be_eligible(order)
      end
    end

    context "with 'none' match policy" do
      before { rule.preferred_match_policy = 'none' }

      it "should be eligible if none of the order's products are in eligible products" do
        allow(order).to receive_messages(:products => [@product1])
        allow(rule).to receive_messages(:eligible_products => [@product2, @product3])
        expect(rule).to be_eligible(order)
      end

      it "should not be eligible if any of the order's products are in eligible products" do
        allow(order).to receive_messages(:products => [@product1, @product2])
        allow(rule).to receive_messages(:eligible_products => [@product2, @product3])
        expect(rule).not_to be_eligible(order)
      end
    end
  end
end
