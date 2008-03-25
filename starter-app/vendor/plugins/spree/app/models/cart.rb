class Cart < ActiveRecord::Base
  has_many :cart_items, :dependent => :destroy do
    def in_cart(product, variant = nil)
      if variant
        find :first, :conditions => ['product_id = ? and variant_id = ?', product.id, variant.id]
      else
        find :first, :conditions => ['product_id = ?', product.id]
      end
    end
  end
  has_many :products, :through => :cart_items

  def total
    cart_items.inject(0) {|sum, n| n.price * n.quantity + sum}
  end
  
  def add_product(product, variant = nil)
    current_item = cart_items.in_cart(product, variant)
    if current_item
      current_item.increment_quantity
    else
      current_item = CartItem.new(:quantity => 1, :product => product, :variant => variant)
      cart_items << current_item
    end
    current_item
  end
  
  def remove_product(product, variant = nil)
    current_item = cart_items.in_cart(product, variant)
    if current_item.quantity > 1
      current_item.decrement_quantity
    else
      CartItem.destroy(current_item.id)
    end
    current_item
  end
end
