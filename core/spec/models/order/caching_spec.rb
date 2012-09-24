require 'spec_helper'

describe Spree::Order do
  let(:product) { Factory(:product) }

  before do
    @order = Factory(:order_with_totals)
    @orig_cache_key = @order.rate_hash_cache_key

    Rails.cache.write(@order.rate_hash_cache_key,"foo")
  end

  context "#updating the order number" do
    it "should invalidate the cache" do
      @order.number = "1234"
      @order.save!

      Rails.cache.exist?(@orig_cache_key).should be_false
    end
  end

  context "#updating the ship address" do
    it "should invalidate the cache" do
      @order.ship_address = Factory(:address)
      @order.save!

      Rails.cache.exist?(@orig_cache_key).should be_false
    end
  end

  context "#changing a line item quantity" do
    it "should invalidate the cache" do
      
      line_item = @order.add_variant(product.master)
      Rails.cache.write(@orig_cache_key,"foo")

      line_item.quantity += 1
      line_item.save!

      Rails.cache.exist?(@orig_cache_key).should be_false
    end
  end

  context "#adding a line item" do
    it "should invalidate the cache" do
      @order.add_variant(product.master)
      Rails.cache.exist?(@orig_cache_key).should be_false
    end
  end

  context "#removing a line item" do
    it "should invalidate the cache" do
      line_item = @order.add_variant(product.master)
      Rails.cache.write(@orig_cache_key,"foo")

      line_item.update_attributes(:quantity => 0)

      @order.line_items = @order.line_items.select {|li| li.quantity > 0 }
      Rails.cache.exist?(@orig_cache_key).should be_false
    end
  end

end
