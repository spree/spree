module Spree
  class AppDependencies
    include Spree::DependenciesHelper

    INJECTION_POINTS = [
      :ability_class,
      :cart_create_service, :cart_add_item_service, :cart_remove_item_service,
      :cart_remove_line_item_service, :cart_set_item_quantity_service, :cart_recalculate_service,
      :cart_update_service, :checkout_next_service, :checkout_advance_service, :checkout_update_service,
      :checkout_complete_service, :checkout_add_store_credit_service,
      :checkout_remove_store_credit_service, :checkout_get_shipping_rates_service,
      :coupon_handler, :country_finder, :current_order_finder, :credit_card_finder,
      :completed_order_finder, :order_sorter, :cart_compare_line_items_service, :collection_paginator, :products_sorter,
      :products_finder, :taxon_finder, :line_item_by_variant_finder, :cart_estimate_shipping_rates_service,
      :account_create_address_service, :account_update_address_service, :address_finder
    ].freeze

    attr_accessor *INJECTION_POINTS

    def initialize
      set_default_ability
      set_default_services
      set_default_finders
    end

    private

    def set_default_ability
      @ability_class = 'Spree::Ability'
    end

    def set_default_services
      # cart
      @cart_compare_line_items_service = 'Spree::CompareLineItems'
      @cart_create_service = 'Spree::Cart::Create'
      @cart_add_item_service = 'Spree::Cart::AddItem'
      @cart_update_service = 'Spree::Cart::Update'
      @cart_recalculate_service = 'Spree::Cart::Recalculate'
      @cart_remove_item_service = 'Spree::Cart::RemoveItem'
      @cart_remove_line_item_service = 'Spree::Cart::RemoveLineItem'
      @cart_set_item_quantity_service = 'Spree::Cart::SetQuantity'
      @cart_estimate_shipping_rates_service = 'Spree::Cart::EstimateShippingRates'

      # checkout
      @checkout_next_service = 'Spree::Checkout::Next'
      @checkout_advance_service = 'Spree::Checkout::Advance'
      @checkout_update_service = 'Spree::Checkout::Update'
      @checkout_complete_service = 'Spree::Checkout::Complete'
      @checkout_add_store_credit_service = 'Spree::Checkout::AddStoreCredit'
      @checkout_remove_store_credit_service = 'Spree::Checkout::RemoveStoreCredit'
      @checkout_get_shipping_rates_service = 'Spree::Checkout::GetShippingRates'

      # sorter
      @order_sorter = 'Spree::Orders::Sort'
      @products_sorter = 'Spree::Products::Sort'

      # paginator
      @collection_paginator = 'Spree::Shared::Paginate'

      # coupons
      # TODO: we should split this service into 2 seperate - Add and Remove
      @coupon_handler = 'Spree::PromotionHandler::Coupon'

      # account
      @account_create_address_service = 'Spree::Account::Addresses::Create'
      @account_update_address_service = 'Spree::Account::Addresses::Update'
    end

    def set_default_finders
      @address_finder = 'Spree::Addresses::Find'
      @country_finder = 'Spree::Countries::Find'
      @current_order_finder = 'Spree::Orders::FindCurrent'
      @completed_order_finder = 'Spree::Orders::FindComplete'
      @credit_card_finder = 'Spree::CreditCards::Find'
      @products_finder = 'Spree::Products::Find'
      @taxon_finder = 'Spree::Taxons::Find'
      @line_item_by_variant_finder = 'Spree::LineItems::FindByVariant'
    end
  end
end
