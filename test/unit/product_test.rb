# These tests are organized into four product configuration quadrants as follows:
#
#   product
#     w/o variants
#         w/o inventory
#         w/inventory
#
#   product
#     w/variants
#         w/o inventory
#         w/inventory
#
# Reusable context taken from:
#   http://www.viget.com/extend/reusing-contexts-in-shoulda-with-context-macros/
#
# Additionally, some basic tests for Product.new vs. Product.create are defined to test
# that Product creation vs instantiated behave the normal "rails way"
#
require 'test_helper'

class ProductTest < ActiveSupport::TestCase

  def self.should_pass_basic_tests
    subject { @product }
    should "have a product" do
      assert @product.is_a?(Product)
    end
    should_validate_presence_of :name
    should "have 'Foo Bar' as name" do
      assert_equal @product.name, "Foo Bar"
    end
    should "have 'foo-bar' as permalink" do
      assert_equal "foo-bar", @product.permalink
    end
    should "not change permalink when name changes" do
      @product.update_attributes :name => 'Foo BaZ'
      assert_equal @product.name, 'Foo BaZ'
      assert_equal 'foo-bar', @product.permalink
    end
    should "not obscure deleted_at" do
      assert true, @product.deleted_at.nil?
    end
    should "not be deleted" do
      assert !@product.deleted?
    end
    should "have a price" do
      assert_equal 19.99, @product.price
    end
    should "have a master price" do
      assert_equal @product.price, @product.master.price
      assert_equal @product.price, @product.price # deprecated, to be removed
    end
    should "change master price when price changes" do
      @product.update_attributes(:price => 30.0)
      assert_equal @product.price, @product.master.price
      assert_equal 30.0, @product.price
    end
    should "change price when master price changes" do
      @product.master.update_attributes(:price => 50.0)
      assert_equal @product.price, @product.master.price
      assert_equal 50.0, @product.price
    end
    should "persist a master variant record" do
      assert_equal @master_variant, @product.master
    end
    should "have a sku" do
      assert_equal 'ABC', @product.sku
    end
    context "when sku is changed" do
      setup { @product.sku = "NEWSKU" }
      should_change("@product.sku", :from => "ABC", :to => "NEWSKU") { @product.sku }
      should_change("@product.master.sku", :from => "ABC", :to => "NEWSKU") { @product.master.sku }
    end
  end

  def self.context_created_product(&block)
    context "Created Product" do
      setup do
        @product = Factory(:product, :name => "Foo Bar")
        @master_variant = Variant.find_by_product_id(@product.id, :conditions => ["is_master = ?", true])
      end
      teardown do
        @product.destroy
      end

      merge_block(&block) if block_given?
    end
  end

  def self.context_without_variants(&block)
    context "without variants" do
      should_pass_basic_tests
      should "return false for has_variants?" do
        assert !@product.has_variants?
      end

      merge_block(&block) if block_given?
    end
  end

  def self.context_with_variants(&block)
    context "with variants" do
      setup do
        @product.variants << Factory(:variant)
        @first_variant = @product.variants.first
      end
      teardown { @first_variant.destroy }
      should_pass_basic_tests
      should "have variants" do
        assert @product.has_variants?
        assert @first_variant.is_a?(Variant)
      end
      should "return true for has_variants?" do
        assert @product.has_variants?
      end

      merge_block(&block) if block_given?
    end
  end

  def self.context_without_inventory_units(&block)
    context "without inventory units" do
      should_pass_basic_tests
      should "return zero on_hand value" do
        assert_equal 0, @product.on_hand
      end
      should "return true for master.has_stock?" do
        assert !@product.master.in_stock?
      end
      should "return false for has_stock?" do
        assert !@product.has_stock?
      end

      merge_block(&block) if block_given?
    end
  end

  def self.should_pass_inventory_tests
    should "return true for has_stock?" do
      assert @product.has_stock?
    end
    should "have on_hand greater than zero" do
      assert @product.on_hand > 0
    end
  end

  context "New Product" do
    setup do
      @product = Factory.build(:product)
    end

    should_not_change("Product.count") { Product.count }
    should_not_change("Variant.count") { Variant.count }
    should "not have a product id" do
      assert @product.id.nil?
    end
  end

  context "New Product instantiated with on_hand" do
    setup do
      @product = Product.new(:name => "fubaz", :price => "10.0", :on_hand => 5)
    end
    should "not have a product id" do
      assert @product.id.nil?
    end
    should_not_change("Product.count") { Product.count }
    should_not_change("Variant.count") { Variant.count }
    should_not_change("InventoryUnit.count") { InventoryUnit.count }
    should "have a Product class" do
      assert @product.is_a?(Product)
    end
    should "have specified on_hand" do
      assert_equal 5, @product.on_hand
    end
  end

  context "Product created with on_hand" do
    setup do
      @product = Product.create(:name => "fubaz", :price => "10.0", :on_hand => 7)
    end
    teardown do
      @product.destroy
    end
    should "have the specified on_hand" do
      assert_equal 7, @product.on_hand
    end
  end

  context_created_product do
    context_without_variants do
      context_without_inventory_units do

      end
      context "with inventory units" do
        setup { @product.master.on_hand = 1 }
        teardown { }
        should_pass_inventory_tests
        should "be true for has_stock?" do
          assert @product.has_stock?
          assert @product.master.in_stock?
        end
        context "when on_hand is increased" do
          setup { @product.update_attribute("on_hand", 5) }
          should_change("@product.on_hand", :by => 4) { @product.on_hand }
          should "have the specified on_hand" do
            assert_equal 5, @product.on_hand
          end
        end
        context "when on_hand is decreased" do
          setup { @product.on_hand = 3 }
          should_change("@product.on_hand", :by => 2) { @product.on_hand }
          should "have the specified on_hand" do
            assert_equal 3, @product.on_hand
          end
        end
      end
    end
  end

  context_created_product do
    context_with_variants do
      context_without_inventory_units
      context "with inventory units" do
        setup do
          @first_variant.on_hand = 1
        end
        teardown { }
        should_pass_inventory_tests
        should "be true for has_stock?" do
          assert !@product.master.in_stock?
          assert @first_variant.in_stock?
          assert @product.has_stock?
        end
        should "have one inventory unit initially" do
          assert 1, @first_variant.inventory_units.count
        end
        context "when on_hand is increased" do
          setup { @first_variant.on_hand = 5 }
          should_change("@product.on_hand", :by => 4) { @product.on_hand }
          should "have the specified on_hand" do
            assert_equal 5, @product.on_hand
          end
        end
        context "when on_hand is decreased" do
          setup { @first_variant.on_hand = 3 }
          should_change("@product.on_hand", :by => 2) { @product.on_hand }
          should "have the specified on_hand" do
            assert_equal 3, @product.on_hand
          end
        end
      end
    end
  end

  context "Product.available" do
    setup do
      5.times { Factory(:product, :available_on => Time.now - 1.day) }
      Factory(:product, :available_on => Time.now - 15.minutes)
      @future_product = Factory.create(:product, :available_on => Time.now + 2.weeks)
    end
    teardown do
      Product.available.destroy_all
      @future_product.destroy
    end
    should "only include available products" do
      assert_equal 6, Product.available.size
      assert !Product.available.include?(@future_product)
    end
  end

  context "instance" do
    setup { @product = Factory(:product, :price => 19.99) }
    context "with a change in price" do
      setup do
        @product.price = 1.11
        @product.save
      end
      should "change the save the new master price" do
        assert_equal BigDecimal.new("1.11"), @product.reload.price
      end
    end
  end

  should 'be deleted if deleted_at is set' do
    @product = Factory.build(:product, :deleted_at => Time.now)
    assert @product.deleted?
  end
end
