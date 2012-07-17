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

  context "price" do
    let!(:product) { Factory(:product, :price => 15) }

    it ".price_between" do
      Spree::Product.price_between(10, 20).first.should == product
      Spree::Product.price_between(30, 40).first.should be_nil
    end

    it ".master_price_lte" do
      pending
      Spree::Product.master_price_lte(20).first.should == product
      Spree::Product.master_price_lte(10).first.should be_nil
    end

    it ".master_price_gte" do
      pending
      Spree::Product.master_price_gte(10).first.should == product
      Spree::Product.master_price_gte(20).first.should be_nil
    end
  end

  context "in taxons" do
    let!(:taxon_1) { Factory(:taxon) }
    let!(:taxon_2) { Factory(:taxon, :parent => taxon_1) }

    let!(:product) do
      product = Factory(:product)
      product.taxons << taxon_1
      product
    end

    let!(:product_2) do
      product = Factory(:product)
      product.taxons << taxon_2
      product
    end

    it ".in_taxon" do
      pending
      taxon_1products = Spree::Product.in_taxon(taxon_1.reload)
      taxon_1_products.should include(product)
      taxon_1_products.should include(product_2)

      taxon_2_products = Spree::Product.in_taxon(taxon_2)
      taxon_2_products.should include(product_2)
      taxon_2_products.should_not include(product)
    end

    it ".in_taxons" do
      pending
      taxon_3 = Factory(:taxon)
      product.taxons << taxon_3
      Spree::Product.in_taxons(taxon_1, taxon_3).first.should == product
    end
  end

  it ".in_cached_group" do
    product = Factory(:product)
    product_group = Factory(:product_group)
    product_group.products << product
    Spree::Product.in_cached_group(product_group).should include(product)
  end


  context ".with_property" do
    let!(:property) do
      Factory(:property, :name => "foo")
    end

    let!(:product) do
      product = Factory(:product)
      product.properties << property
      product
    end

    let!(:other_product) { Factory(:product) }

    it "by string" do
      products = Spree::Product.with_property("foo")
      products.should include(product)
      products.should_not include(other_product)
    end

    it "by property object" do
      products = Spree::Product.with_property(property)
      products.should include(product)
      products.should_not include(other_product)
    end

    it "by unknown (assumed to be an id-like substance)" do
      products = Spree::Product.with_property(property.id)
      products.should include(product)
      products.should_not include(other_product)
    end
  end

  context ".with_option" do
    let!(:option_type) do
      Factory(:option_type, :name => "foo")
    end

    let!(:product) do
      product = Factory(:product)
      product.option_types << option_type
      product
    end

    let!(:other_product) { Factory(:product) }

    it "by string" do
      products = Spree::Product.with_option("foo")
      products.should include(product)
      products.should_not include(other_product)
    end

    it "by OptionType object" do
      products = Spree::Product.with_option(option_type)
      products.should include(product)
      products.should_not include(other_product)
    end

    it "by unknown (assumed to be an id-like substance)" do
      products = Spree::Product.with_option(option_type.id)
      products.should include(product)
      products.should_not include(other_product)
    end
  end

  context ".with_option_value" do
    let!(:option_type) { Factory(:option_type, :name => "foo") }
    let!(:option_value) { Factory(:option_value, :option_type => option_type, :name => "bar") }
    let!(:product) do
      product = Factory(:product)
      product.master.option_values << option_value
      product.master.save
      product
    end

    let!(:other_product) { Factory(:product) }

    it "by string" do
      products = Spree::Product.with_option_value("foo", "bar")
      products.should include(product)
      products.should_not include(other_product)
    end

    it "by OptionType" do
      products = Spree::Product.with_option_value(option_type, "bar")
      products.should include(product)
      products.should_not include(other_product)
    end

    it "by unknown (assumed to be id-like substance)" do
      products = Spree::Product.with_option_value(option_type.id, "bar")
      products.should include(product)
      products.should_not include(other_product)
    end
  end

  context ".with_property_value" do
    let!(:property) { Factory(:property, :name => "foo") }
    let!(:product) { Factory(:product) }

    before do
      Spree::ProductProperty.create!({
        :product => product,
        :property => property,
        :value => "bar"},
      :without_protection => true)
    end

    let!(:other_product) { Factory(:product) }

    it "by string" do
      products = Spree::Product.with_property_value("foo", "bar")
      products.should include(product)
      products.should_not include(other_product)
    end

    it "by Property object" do
      products = Spree::Product.with_property_value(property, "bar")
      products.should include(product)
      products.should_not include(other_product)
    end

    it "by unknown (assumed to be an id-like substance)" do
      products = Spree::Product.with_property_value(property.id, "bar")
      products.should include(product)
      products.should_not include(other_product)
    end
  end

  context ".with" do
    let!(:product) { Factory(:product) }
    let!(:other_product) { Factory(:product) }

    it "property value" do
      property = Factory(:property)
      Spree::ProductProperty.create!({
        :product => product,
        :property => property,
        :value => "foo"},
        :without_protection => true)

      products = Spree::Product.with("foo")
      products.should include(product)
      products.should_not include(other_product)
    end

    it "option value" do
      option_value = Factory(:option_value, :name => "bar")
      product.master.option_values << option_value
      product.master.save

      products = Spree::Product.with("bar")
      products.should include(product)
      products.should_not include(other_product)
    end
  end

  context ".in" do
    let!(:product) do
      Factory(:product, :name => "foobar",
                        :meta_keywords => "baz",
                        :meta_description => "baa",
                        :description => "wow")
    end

    let!(:other_product) { Factory(:product, :name => "fizzbuzz") }

    it ".in_name" do
      products = Spree::Product.in_name("foo")

      products.should include(product)
      products.should_not include(other_product)
    end

    it ".in_name_or_keywords" do
      products = Spree::Product.in_name_or_keywords("baz")

      products.should include(product)
      products.should_not include(other_product)
    end

    context ".in_name_or_description" do
      it "meta_description" do
        products = Spree::Product.in_name_or_description("baa")

        products.should include(product)
        products.should_not include(other_product)

        products
      end

      it "description" do
        products = Spree::Product.in_name_or_description("wow")
        products.should include(product)
        products.should_not include(other_product)
      end
    end
  end

  context ".with_ids" do
    let!(:product) { Factory(:product) }
    let!(:other_product) { Factory(:product) }

    it "with a collection of ids" do
      products = Spree::Product.with_ids(product.id, other_product.id)
      products.should include(product)
      products.should include(other_product)
    end
  end

  it ".descend_by_popularity" do
    product = Factory(:product)
    line_item = Factory(:line_item, :variant => product.master)

    other_product = Factory(:product)

    products = Spree::Product.descend_by_popularity.to_a
    products.first.should == product
    products.last.should == other_product
  end

  it ".not_deleted" do
    product = Factory(:product)
    other_product = Factory(:product)
    other_product.update_attribute(:deleted_at, Time.now)

    products = Spree::Product.not_deleted
    products.should include(product)
    other_product.should be_persisted
    products.should_not include(other_product)
  end

  it ".available" do
    product = Factory(:product, :available_on => 1.day.ago)
    other_product = Factory(:product, :available_on => 1.day.from_now)

    todays_products = Spree::Product.available
    todays_products.should include(product)
    todays_products.should_not include(other_product)

    future_products = Spree::Product.available(2.days.from_now)
    future_products.should include(product)
    future_products.should include(other_product)
  end

  it ".on hand" do
    product = Factory(:product)
    product.master.update_attribute(:count_on_hand, 1)
    product.save!

    other_product = Factory(:product)
    other_product.master.update_attribute(:count_on_hand, -1)
    other_product.save!

    products = Spree::Product.on_hand
    products.should include(product)
    products.should_not include(other_product)
  end

  it ".with variant no on hand" do
    Spree::Config.set :track_inventory_levels => true
    product = Factory(:product)
    product.master.update_attribute(:on_hand, 0)
    variant = Factory(:variant, :product => product, :on_hand => 100, :is_master => false, :deleted_at => nil)
    product.save!
    Spree::Product.on_hand.should include(variant.product)
  end

  it ".taxons_name_eq" do
    taxon = Factory(:taxon)
    product = Factory(:product)
    product.taxons << taxon

    other_product = Factory(:product)

    products = Spree::Product.taxons_name_eq(taxon.name)
    products.should include(product)
    products.should_not include(other_product)
  end
end
