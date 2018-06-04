module Spree
  class OrderContents
    attr_accessor :order, :currency

    def initialize(order)
      @order = order
    end

    def add(variant, quantity = 1, options = {})
      ActiveSupport::Deprecation.warn(<<-EOS, caller)
        OrderContents#add method is deprecated and will be removed in Spree 4.0. Please use Spree::Cart::AddItem service
        to add items to cart.
      EOS

      Spree::Cart::AddItem.call(order: order, variant: variant, quantity: quantity, options: options).value
    end

    def remove(variant, quantity = 1, options = {})
      ActiveSupport::Deprecation.warn(<<-EOS, caller)
        OrderContents#remove method is deprecated and will be removed in Spree 4.0. Please use Spree::Cart::RemoveItem
        service to remove item from cart.
      EOS

      Spree::Cart::RemoveItem.call(order: order, variant: variant, quantity: quantity, options: options).value
    end

    def remove_line_item(line_item, options = {})
      ActiveSupport::Deprecation.warn(<<-EOS, caller)
        OrderContents#remove_line_item method is deprecated and will be removed in Spree 4.0.
      EOS

      Spree::Cart::RemoveLineItem.call(order: @order, line_item: line_item, options: options).value
    end

    def update_cart(params)
      ActiveSupport::Deprecation.warn(<<-EOS, caller)
        OrderContents#update_cart method is deprecated and will be removed in Spree 4.0. Please use Spree::Cart::Update
        service to update cart.
      EOS

      Spree::Cart::Update.call(order: order, params: params).value
    end
  end
end
