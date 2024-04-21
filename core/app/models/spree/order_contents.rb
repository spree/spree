module Spree
  class OrderContents
    attr_accessor :order, :currency

    def initialize(order)
      @order = order
    end

    def add(variant, quantity = 1, options = {})
      Spree::Dependencies.cart_add_item_service.constantize.call(order: order,
                                                                 variant: variant,
                                                                 quantity: quantity,
                                                                 options: options).value
    end

    def remove(variant, quantity = 1, options = {})
      Spree::Dependencies.cart_remove_item_service.constantize.call(order: order,
                                                                    variant: variant,
                                                                    quantity: quantity,
                                                                    options: options).value
    end

    def remove_line_item(line_item, options = {})
      Spree::Cart::RemoveLineItem.call(order: @order, line_item: line_item, options: options).value
    end

    def update_cart(params)
      Spree::Dependencies.cart_update_service.constantize.call(order: order, params: params).value
    end
  end
end
