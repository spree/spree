require 'spec_helper'

describe "product scopes" do
  context "by_updated_at" do
    let!(:product_1) { Factory(:product, :updated_at => 1.day.ago) }
    let!(:product_2) { Factory(:product, :updated_at => 1.day.from_now) }

    it "ascending" do
      Spree::Product.ascend_by_updated_at.should == [product_1, product_2]
    end

    it "descending" do
      Spree::Product.descend_by_updated_at.should == [product_2, product_1]
    end
  end

  context "by_name" do
    let!(:product_1) { Factory(:product, :name => "Alpha") }
    let!(:product_2) { Factory(:product, :name => "Zeta") }

    it "ascending" do
      Spree::Product.ascend_by_name.should == [product_1, product_2]
    end

    it "descending" do
      Spree::Product.descend_by_name.should == [product_2, product_1]
    end
  end

  context "condition finders" do
    let!(:product) { Factory(:product, :name => "Alpha") }
    it ".conditions" do
      Spree::Product.conditions("name = ?", "Alpha").first.should == product
    end

    it ".conditions_all" do
      Spree::Product.conditions("name = ?", "Alpha").first.should == product
    end

    it ".conditions_any" do
      product_2 = Factory(:product, :name => "Beta")
      products = Spree::Product.conditions_any("name = 'Beta'", "name = 'Alpha'")
      products.should include(product)
      products.should include(product_2)
    end

  end

end
