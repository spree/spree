require 'test_helper'

class VariantTest < ActiveSupport::TestCase

  context "A new Variant" do
    context "without inventory units" do
      setup { @variant = Variant.new }
      should "not have inventory units" do
        assert 0, @variant.inventory_units.size
      end
      should "on_hand should be zero" do
        assert 0, @variant.on_hand
      end
      should "not be deleted" do
        assert !@variant.deleted?
      end
    end

    context "with specified on_hand" do
      setup { @variant = Variant.new(:on_hand => 5) }
      should "have inventory units" do
        assert 5, @variant.inventory_units.size
      end
      should "on_hand should match specified units" do
        assert 5, @variant.on_hand
      end
      should_not_change("InventoryUnit.count") { InventoryUnit.count }
    end
  end

  context "Variant.create" do
    setup do
      @product = Factory(:product)
      @product.master.price = 10.99
    end
    teardown { @product.destroy }
    context "with price specified" do
      setup do
        @variant = Variant.create(:product => @product, :name => 'foo bar', :price => 11.33)
      end
      teardown { @variant.destroy }
      should "ignore the product's master price" do
        assert_in_delta @variant.price, 11.33, 0.00001
      end
      should_not_change("InventoryUnit.count") { InventoryUnit.count }
    end
    context "with no price specified" do
      setup do
        @variant = Variant.create(:product => @product)
      end
      teardown { @variant.destroy }
      should "use the product's master price" do
        assert_in_delta @variant.price, 10.99, 0.00001
      end
      should_not_change("InventoryUnit.count") { InventoryUnit.count }
    end
    context "with specified inventory level" do
      setup do
        @variant = Variant.new(:on_hand => 3)
        @product.variants << @variant
        @product.save
      end
      teardown do
        @variant.destroy
      end
      should "adjust inventory levels" do
        assert_equal 3, @variant.on_hand
        assert_equal 3, @variant.product.reload.count_on_hand
      end

      should_not_change("InventoryUnit.count") { InventoryUnit.count }
    end
  end
  context "Variant instance with 1 unit of inventory" do
    setup do
      @variant = Factory(:variant)
      @variant.on_hand = 1
    end
    teardown do
      @variant.destroy
    end
    should "return true for in_stock?" do
      assert @variant.in_stock?
    end
    context "when on_hand is increased" do
      setup { @variant.update_attribute("on_hand", 5) }
      should_change("@variant.on_hand", :by => 4) { @variant.on_hand }
      should_not_change("InventoryUnit.count") { InventoryUnit.count }
      should "return correct amount for on_hand" do
        assert_equal 5, @variant.on_hand
      end
    end
    context "when on_hand is changed to 0 and backorders are NOT allowed" do
      setup do
        @variant.update_attribute("on_hand", "0")
        Spree::Config.set(:allow_backorders => false)
      end
      teardown do
        @variant.inventory_units.destroy_all
        @variant.destroy
      end
      should_change("@variant.on_hand", :by => -1) { @variant.on_hand }
      should_not_change("InventoryUnit.count") { InventoryUnit.count }
      should "return correct amount for on_hand" do
        assert_equal 0, @variant.on_hand
      end
      should "return false for in_stock?" do
        assert !@variant.in_stock?
      end
      should "return false for available?" do
        assert !@variant.available?
      end
    end
    context "when on_hand is changed to 0 and backorders are allowed" do
      setup do
        @variant.update_attribute("on_hand", "0")
        Spree::Config.set(:allow_backorders => true)
      end
      teardown do
        @variant.inventory_units.destroy_all
        @variant.destroy
      end
      should_change("@variant.on_hand", :by => -1) { @variant.on_hand }
      should_not_change("InventoryUnit.count") { InventoryUnit.count }
      should "return correct amount for on_hand" do
        assert_equal 0, @variant.on_hand
      end
      should "return false for in_stock?" do
        assert !@variant.in_stock?
      end
      should "return false for available?" do
        assert @variant.available?
      end
    end
  end

  should 'be deleted if deleted_at is set' do
    @variant = Variant.new(:deleted_at => Time.now)
    assert @variant.deleted?
  end
end
