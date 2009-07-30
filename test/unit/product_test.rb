require 'test_helper'

class ProductTest < Test::Unit::TestCase
  context "Product instance" do
    context "with both empty and non-empty variants" do
      setup { @product = Factory(:product) }
      should_validate_presence_of :name, :master_price
      should "return true for variants?" do
        assert @product.variants?
      end
      should "return nil for variant" do
        assert_nil @product.variant
      end
    end
    
    context "with product name of 'Foo Product Deluxe'" do
      setup { @product = Factory(:product, :name => "Foo Product Deluxee") }
      should "have correct permalink" do
        assert_equal "foo-product-deluxee", @product.permalink
      end
    end

    context "with no variants exist" do
      setup { @product = Factory(:product, :variants => []) }
      should "return false for variants?" do
        assert !@product.variants?
      end
      should "return nil for variant" do
        assert_nil @product.variant
      end
    end

    context "with only empty variant and no units of inventory" do
      setup do
        @empty_variant = Factory(:empty_variant, :sku => "FOOSKU")
        @product = Factory(:product, :variants => [@empty_variant])
      end
      should "return false for has_stock?" do
        assert !@product.has_stock?
      end
    end
    
    context "with only empty variant and 1 unit of inventory" do
      setup do
        @empty_variant = Factory(:empty_variant, :sku => "FOOSKU", :inventory_units => [Factory(:inventory_unit)])
        @product = Factory(:product, :variants => [@empty_variant])
      end
      should "return false for variants?" do
        assert !@product.variants?
      end
      should "return the empty_variant for variant" do
        assert_equal @empty_variant, @product.variant
      end
      should "return the correct on_hand value" do
        assert_equal 1, @product.on_hand
      end
      should "return the correct sku value" do
        assert_equal @empty_variant.sku, @product.sku
      end
      should "return true for has_stock?" do
        assert @product.has_stock?
      end
      context "when sku is changed" do
        setup { @product.sku = "NEWSKU" }
        should_change "@empty_variant.sku", :from => "FOOSKU", :to => "NEWSKU"
      end
      context "when master price changes" do
        setup { @product.update_attribute("master_price", 99.99) }
        should "change the empty variant price to the same value" do
          assert_in_delta @empty_variant.price, 99.99, 0.00001          
        end
      end
      context "when on_hand is increased" do
        setup { @product.update_attribute("on_hand", "5") }
        should_change "InventoryUnit.count", :by => 4
      end
      context "when on_hand is decreased" do
        setup do 
          @product.update_attribute("on_hand", "0")
          @empty_variant.reload
        end
        should_change "InventoryUnit.count", :by => -1
      end
    end
  end
  
  context "Product.available" do
    setup do
      Product.destroy_all
      5.times { Factory(:product, :available_on => Time.now - 1.day) }
      @unavaiable = Factory(:product, :available_on => Time.now + 2.weeks) 
    end
    should "only include available products" do
      assert_equal 5, Product.available.size
      assert !Product.available.include?(@unavailable)
    end
  end
  
  context "Product.create" do
    setup { Product.create(Factory.attributes_for(:product).merge(:on_hand => "7", :variants => [Factory(:empty_variant)])) }
    should_change "InventoryUnit.count", :by => 7
  end
  
end