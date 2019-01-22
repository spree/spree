module Spree
  class AppDependencies < Preferences::Configuration
    def initialize
      set_default_services
      set_default_finders
    end

    attr_accessor :cart_create_service, :cart_add_item_service, :cart_remove_item_service,
                  :cart_remove_line_item_service, :cart_set_item_quantity_service,
                  :checkout_next_service, :checkout_advance_service, :checkout_update_service,
                  :checkout_complete_service, :checkout_add_store_credit_service,
                  :checkout_remove_store_credit_service, :checkout_get_shipping_rates_service,
                  :coupon_handler, :country_finder, :current_order_finder, :credit_card_finder,
                  :completed_order_finder, :order_sorter, :collection_paginator, :products_sorter,
                  :products_finder, :taxon_finder

    private

    def set_default_services
      # cart
      @cart_create_service = 'Spree::Cart::Create'
      @cart_add_item_service = 'Spree::Cart::AddItem'
      @cart_remove_item_service = 'Spree::Cart::RemoveItem'
      @cart_remove_line_item_service = 'Spree::Cart::RemoveLineItem'
      @cart_set_item_quantity_service = 'Spree::Cart::SetQuantity'

      # checkout
      @checkout_next_service = 'Spree::Checkout::Next'
      @checkout_advance_service = 'Spree::Checkout::Advance'
      @checkout_update_service = 'Spree::Checkout::Update'
      @checkout_complete_service = 'Spree::Checkout::Complete'
      @checkout_add_store_credit_service = 'Spree::Checkout::AddStoreCredit'
      @checkout_remove_store_credit_service = 'Spree::Checkout::RemoveStoreCredit'
      @checkout_get_shipping_rates_service = 'Spree::Checkout::GetShippingRates'

      #sorter
      @order_sorter = 'Spree::Orders::Sort'
      @products_sorter = 'Spree::Products::Sort'

      #paginator
      @collection_paginator = 'Spree::Shared::Paginate'

      # coupons
      # TODO: we should split this service into 2 seperate - Add and Remove
      @coupon_handler = 'Spree::PromotionHandler::Coupon'
    end

    def set_default_finders
      @country_finder = 'Spree::Countries::Find'
      @current_order_finder = 'Spree::Orders::FindCurrent'
      @completed_order_finder = 'Spree::Orders::FindComplete'
      @credit_card_finder = 'Spree::CreditCards::Find'
      @products_finder = 'Spree::Products::Find'
      @taxon_finder = 'Spree::Taxons::Find'
    end
  end
end
