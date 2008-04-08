class Cart < ActiveRecord::Base
  has_many :cart_items, :dependent => :destroy do
    def in_cart(variant)
      find :first, :conditions => ['variant_id = ?', variant.id]
    end
  end
  has_many :products, :through => :cart_items

  def total
    cart_items.inject(0) {|sum, n| n.price * n.quantity + sum}
  end
  
  def add_variant(variant, quantity=1)
    current_item = cart_items.in_cart(variant)
    if current_item
      current_item.increment_quantity unless quantity > 1
      current_item.quantity = (current_item.quantity + quantity) if quantity > 1
    else
      current_item = CartItem.new(:quantity => quantity, :variant => variant)
      cart_items << current_item
    end
    current_item
  end
end
