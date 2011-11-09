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

  context "price" do
    let!(:product) { Factory(:product, :price => 15) }

    it ".price_between" do
      Spree::Product.price_between(10, 20).first.should == product
      Spree::Product.price_between(30, 40).first.should be_nil
    end

    it ".master_price_lte" do
      Spree::Product.master_price_lte(20).first.should == product
      Spree::Product.master_price_lte(10).first.should be_nil
    end

    it ".master_price_gte" do
      Spree::Product.master_price_gte(10).first.should == product
      Spree::Product.master_price_gte(20).first.should be_nil
    end
  end

  it ".in_taxon" do
    taxon_1 = Factory(:taxon)
    taxon_2 = Factory(:taxon, :parent => taxon_1)

    product = Factory(:product)
    product.taxons << taxon_1
    product.save!

    product_2 = Factory(:product)
    product_2.taxons << taxon_2
    product_2.save!

    taxon_1_products = Spree::Product.in_taxon(taxon_1.reload)
    taxon_1_products.should include(product)
    taxon_1_products.should include(product_2)

    taxon_2_products = Spree::Product.in_taxon(taxon_2)
    taxon_2_products.should include(product_2)
    taxon_2_products.should_not include(product)
  end

end
