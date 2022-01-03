require_relative 'dependencies_helper'

module Spree
  module Core
    class Dependencies
      include Spree::DependenciesHelper

      INJECTION_POINTS = [
        :ability_class,
        :cart_create_service, :cart_add_item_service, :cart_remove_item_service,
        :cart_remove_line_item_service, :cart_set_item_quantity_service, :cart_recalculate_service,
        :cms_page_finder, :cart_update_service, :checkout_next_service, :checkout_advance_service, :checkout_update_service,
        :checkout_complete_service, :checkout_add_store_credit_service, :checkout_remove_store_credit_service, :checkout_get_shipping_rates_service,
        :coupon_handler, :menu_finder, :country_finder, :current_order_finder, :credit_card_finder,
        :completed_order_finder, :order_sorter, :cart_compare_line_items_service, :collection_paginator, :products_sorter,
        :products_finder, :taxon_finder, :line_item_by_variant_finder, :cart_estimate_shipping_rates_service,
        :account_create_address_service, :account_update_address_service, :account_create_service, :account_update_service,
        :address_finder, :collection_sorter, :error_handler, :current_store_finder, :cart_empty_service, :cart_destroy_service,
        :classification_reposition_service, :credit_cards_destroy_service, :cart_associate_service, :cart_change_currency_service,
        :line_item_create_service, :line_item_update_service, :line_item_destroy_service,
        :order_approve_service, :order_cancel_service, :shipment_change_state_service, :shipment_update_service,
        :shipment_create_service, :shipment_add_item_service, :shipment_remove_item_service,
        :payment_create_service, :address_create_service, :address_update_service,
        :checkout_select_shipping_method_service
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
        @cart_empty_service = 'Spree::Cart::Empty'
        @cart_destroy_service = 'Spree::Cart::Destroy'
        @cart_associate_service = 'Spree::Cart::Associate'
        @cart_change_currency_service = 'Spree::Cart::ChangeCurrency'

        # checkout
        @checkout_next_service = 'Spree::Checkout::Next'
        @checkout_advance_service = 'Spree::Checkout::Advance'
        @checkout_update_service = 'Spree::Checkout::Update'
        @checkout_complete_service = 'Spree::Checkout::Complete'
        @checkout_add_store_credit_service = 'Spree::Checkout::AddStoreCredit'
        @checkout_remove_store_credit_service = 'Spree::Checkout::RemoveStoreCredit'
        @checkout_get_shipping_rates_service = 'Spree::Checkout::GetShippingRates'
        @checkout_select_shipping_method_service = 'Spree::Checkout::SelectShippingMethod'

        # order
        @order_approve_service = 'Spree::Orders::Approve'
        @order_cancel_service = 'Spree::Orders::Cancel'

        # shipment
        @shipment_change_state_service = 'Spree::Shipments::ChangeState'
        @shipment_create_service = 'Spree::Shipments::Create'
        @shipment_update_service = 'Spree::Shipments::Update'
        @shipment_add_item_service = 'Spree::Shipments::AddItem'
        @shipment_remove_item_service = 'Spree::Shipments::RemoveItem'

        # sorter
        @collection_sorter = 'Spree::BaseSorter'
        @order_sorter = 'Spree::BaseSorter'
        @products_sorter = 'Spree::Products::Sort'

        # paginator
        @collection_paginator = 'Spree::Shared::Paginate'

        # coupons
        # TODO: we should split this service into 2 separate - Add and Remove
        @coupon_handler = 'Spree::PromotionHandler::Coupon'

        # account
        @account_create_service = 'Spree::Account::Create'
        @account_update_service = 'Spree::Account::Update'

        # addresses
        @address_create_service = 'Spree::Addresses::Create'
        @address_update_service = 'Spree::Addresses::Update'

        # credit cards
        @credit_cards_destroy_service = 'Spree::CreditCards::Destroy'

        # classifications
        @classification_reposition_service = 'Spree::Classifications::Reposition'

        # line items
        @line_item_create_service = 'Spree::LineItems::Create'
        @line_item_update_service = 'Spree::LineItems::Update'
        @line_item_destroy_service = 'Spree::LineItems::Destroy'

        @payment_create_service = 'Spree::Payments::Create'

        # errors
        @error_handler = 'Spree::ErrorReporter'
      end

      def set_default_finders
        @address_finder = 'Spree::Addresses::Find'
        @country_finder = 'Spree::Countries::Find'
        @cms_page_finder = 'Spree::CmsPages::Find'
        @menu_finder = 'Spree::Menus::Find'
        @current_order_finder = 'Spree::Orders::FindCurrent'
        @current_store_finder = 'Spree::Stores::FindCurrent'
        @completed_order_finder = 'Spree::Orders::FindComplete'
        @credit_card_finder = 'Spree::CreditCards::Find'
        @products_finder = 'Spree::Products::Find'
        @taxon_finder = 'Spree::Taxons::Find'
        @line_item_by_variant_finder = 'Spree::LineItems::FindByVariant'
      end
    end
  end
end
