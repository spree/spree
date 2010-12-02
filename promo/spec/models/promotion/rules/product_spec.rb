require 'spec_helper'

describe Promotion::Rules::Product do
  let(:rule) { Promotion::Rules::Product.new }

  context "#eligible_products" do
    it "should return products from products group product_group if it exists" do
      rule.stub(:product_group => stub('product_group', :products => 'products'))
      rule.eligible_products.should == 'products'
    end

    it "should return products if product_group does not exist" do
      rule.stub(:product_group => nil, :products => 'products')
      rule.eligible_products.should == 'products'
    end
  end

  it "should reset product_group_id if given source is manual" do
    rule.product_group_id = 1
    rule.products_source = stub("source", :to_s => 'manual')
    rule.product_group_id.should be_nil
  end

  context "#eligible?(order)" do
    let(:order) { Order.new }

    it "should be eligible if there are no products" do
      rule.stub(:eligible_products => [])
      rule.should be_eligible(order)
    end

    before do
      3.times { |i| instance_variable_set("@product#{i}", mock_model(Product)) }
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
