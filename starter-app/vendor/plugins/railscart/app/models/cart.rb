class Cart < ActiveRecord::Base
  has_many :cart_items, :dependent => :destroy do
    def in_cart(product, variation = nil)
      if variation
        find :first, :conditions => ['product_id = ? and variation_id = ?', product.id, variation.id]
      else
        find :first, :conditions => ['product_id = ?', product.id]
      end
    end
  end
  has_many :products, :through => :cart_items

  def total
    cart_items.inject(0) {|sum, n| n.price * n.quantity + sum}
  end
  
  def add_product(product, variation = nil)
    current_item = cart_items.in_cart(product, variation)
    if current_item
      current_item.increment_quantity
    else
      current_item = CartItem.new(:quantity => 1, :product => product, :variation => variation)
      cart_items << current_item
    end
    current_item
  end
  
  def remove_product(product, variation = nil)
    current_item = cart_items.in_cart(product, variation)
    if current_item.quantity > 1
      current_item.decrement_quantity
    else
      CartItem.destroy(current_item.id)
    end
    current_item
  end
end
