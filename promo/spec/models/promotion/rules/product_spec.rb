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

      it "should not be eligible if none of the products is in eligible products" do
        order.stub(:products => [@product1])
        rule.stub(:eligible_products => [@product2, @product3])
        rule.should_not be_eligible(order)
      end
    end

    context "with 'all' match policy" do
      before { rule.preferred_match_policy = 'all' }

      it "should be eligible if all of the eligible products are ordered" do
        order.stub(:products => [@product3, @product2, @product1])
        rule.stub(:eligible_products => [@product2, @product3])
        rule.should be_eligible(order)
      end

      it "should not be eligible if any of the eligible products is not ordered" do
        order.stub(:products => [@product1, @product2])
        rule.stub(:eligible_products => [@product1, @product2, @product3])
        rule.should_not be_eligible(order)
      end
    end
  end
end
