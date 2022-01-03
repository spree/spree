module Spree
  module Api
    class ApiDependencies
      include Spree::DependenciesHelper

      INJECTION_POINTS = [
        :storefront_cart_create_service, :storefront_cart_add_item_service, :storefront_cart_remove_line_item_service,
        :storefront_cart_remove_item_service, :storefront_cart_set_item_quantity_service, :storefront_cart_recalculate_service,
        :storefront_cms_page_serializer, :storefront_cms_page_finder,
        :storefront_cart_update, :storefront_coupon_handler, :storefront_checkout_next_service, :storefront_checkout_advance_service,
        :storefront_checkout_update_service, :storefront_checkout_complete_service, :storefront_checkout_add_store_credit_service,
        :storefront_checkout_remove_store_credit_service, :storefront_checkout_get_shipping_rates_service,
        :storefront_cart_compare_line_items_service, :storefront_cart_serializer, :storefront_credit_card_serializer,
        :storefront_credit_card_finder, :storefront_shipment_serializer, :storefront_payment_method_serializer, :storefront_country_finder,
        :storefront_country_serializer, :storefront_menu_serializer, :storefront_menu_finder, :storefront_current_order_finder,
        :storefront_completed_order_finder, :storefront_order_sorter, :storefront_collection_paginator, :storefront_user_serializer,
        :storefront_products_sorter, :storefront_products_finder, :storefront_product_serializer, :storefront_taxon_serializer,
        :storefront_taxon_finder, :storefront_find_by_variant_finder, :storefront_cart_update_service, :storefront_cart_associate_service,
        :storefront_cart_estimate_shipping_rates_service, :storefront_estimated_shipment_serializer,
        :storefront_store_serializer, :storefront_address_serializer, :storefront_order_serializer,
        :storefront_account_create_address_service, :storefront_account_update_address_service, :storefront_address_finder,
        :storefront_account_create_service, :storefront_account_update_service, :storefront_collection_sorter, :error_handler,
        :storefront_cart_empty_service, :storefront_cart_destroy_service, :storefront_credit_cards_destroy_service, :platform_products_sorter,
        :storefront_cart_change_currency_service, :storefront_payment_serializer,
        :storefront_payment_create_service, :storefront_address_create_service, :storefront_address_update_service,
        :storefront_checkout_select_shipping_method_service,

        :platform_admin_user_serializer, :platform_coupon_handler, :platform_order_update_service,
        :platform_order_use_store_credit_service, :platform_order_remove_store_credit_service,
        :platform_order_complete_service, :platform_order_empty_service, :platform_order_destroy_service,
        :platform_order_next_service, :platform_order_advance_service,
        :platform_line_item_create_service, :platform_line_item_update_service, :platform_line_item_destroy_service,
        :platform_order_approve_service, :platform_order_cancel_service,
        :platform_shipment_change_state_service, :platform_shipment_create_service, :platform_shipment_update_service,
        :platform_shipment_add_item_service, :platform_shipment_remove_item_service
      ].freeze

      attr_accessor *INJECTION_POINTS

      def initialize
        set_storefront_defaults
        set_platform_defaults
      end

      private

      def set_storefront_defaults
        # cart services
        @storefront_cart_create_service = Spree::Dependencies.cart_create_service
        @storefront_cart_add_item_service = Spree::Dependencies.cart_add_item_service
        @storefront_cart_compare_line_items_service = Spree::Dependencies.cart_compare_line_items_service
        @storefront_cart_update_service = Spree::Dependencies.cart_update_service
        @storefront_cart_remove_line_item_service = Spree::Dependencies.cart_remove_line_item_service
        @storefront_cart_remove_item_service = Spree::Dependencies.cart_remove_item_service
        @storefront_cart_set_item_quantity_service = Spree::Dependencies.cart_set_item_quantity_service
        @storefront_cart_recalculate_service = Spree::Dependencies.cart_recalculate_service
        @storefront_cart_estimate_shipping_rates_service = Spree::Dependencies.cart_estimate_shipping_rates_service
        @storefront_cart_empty_service = Spree::Dependencies.cart_empty_service
        @storefront_cart_destroy_service = Spree::Dependencies.cart_destroy_service
        @storefront_cart_associate_service = Spree::Dependencies.cart_associate_service
        @storefront_cart_change_currency_service = Spree::Dependencies.cart_change_currency_service

        # coupon code handler
        @storefront_coupon_handler = Spree::Dependencies.coupon_handler

        # checkout services
        @storefront_checkout_next_service = Spree::Dependencies.checkout_next_service
        @storefront_checkout_advance_service = Spree::Dependencies.checkout_advance_service
        @storefront_checkout_update_service = Spree::Dependencies.checkout_update_service
        @storefront_checkout_complete_service = Spree::Dependencies.checkout_complete_service
        @storefront_checkout_add_store_credit_service = Spree::Dependencies.checkout_add_store_credit_service
        @storefront_checkout_remove_store_credit_service = Spree::Dependencies.checkout_remove_store_credit_service
        @storefront_checkout_get_shipping_rates_service = Spree::Dependencies.checkout_get_shipping_rates_service
        @storefront_checkout_select_shipping_method_service = Spree::Dependencies.checkout_select_shipping_method_service

        # account services
        @storefront_account_create_service = Spree::Dependencies.account_create_service
        @storefront_account_update_service = Spree::Dependencies.account_update_service

        # address services
        @storefront_address_create_service = Spree::Dependencies.address_create_service
        @storefront_address_update_service = Spree::Dependencies.address_update_service

        # credit card services
        @storefront_credit_cards_destroy_service = Spree::Dependencies.credit_cards_destroy_service

        # payment services
        @storefront_payment_create_service = Spree::Dependencies.payment_create_service

        # serializers
        @storefront_address_serializer = 'Spree::V2::Storefront::AddressSerializer'
        @storefront_cart_serializer = 'Spree::V2::Storefront::CartSerializer'
        @storefront_cms_page_serializer = 'Spree::V2::Storefront::CmsPageSerializer'
        @storefront_credit_card_serializer = 'Spree::V2::Storefront::CreditCardSerializer'
        @storefront_country_serializer = 'Spree::V2::Storefront::CountrySerializer'
        @storefront_menu_serializer = 'Spree::V2::Storefront::MenuSerializer'
        @storefront_user_serializer = 'Spree::V2::Storefront::UserSerializer'
        @storefront_shipment_serializer = 'Spree::V2::Storefront::ShipmentSerializer'
        @storefront_taxon_serializer = 'Spree::V2::Storefront::TaxonSerializer'
        @storefront_payment_method_serializer = 'Spree::V2::Storefront::PaymentMethodSerializer'
        @storefront_payment_serializer = 'Spree::V2::Storefront::PaymentSerializer'
        @storefront_product_serializer = 'Spree::V2::Storefront::ProductSerializer'
        @storefront_estimated_shipment_serializer = 'Spree::V2::Storefront::EstimatedShippingRateSerializer'
        @storefront_store_serializer = 'Spree::V2::Storefront::StoreSerializer'
        @storefront_order_serializer = 'Spree::V2::Storefront::OrderSerializer'

        # sorters
        @storefront_collection_sorter = Spree::Dependencies.collection_sorter
        @storefront_order_sorter = Spree::Dependencies.collection_sorter
        @storefront_products_sorter = Spree::Dependencies.products_sorter
        @platform_products_sorter = Spree::Dependencies.products_sorter

        # paginators
        @storefront_collection_paginator = Spree::Dependencies.collection_paginator

        # finders
        @storefront_address_finder = Spree::Dependencies.address_finder
        @storefront_country_finder = Spree::Dependencies.country_finder
        @storefront_cms_page_finder = Spree::Dependencies.cms_page_finder
        @storefront_menu_finder = Spree::Dependencies.menu_finder
        @storefront_current_order_finder = Spree::Dependencies.current_order_finder
        @storefront_completed_order_finder = Spree::Dependencies.completed_order_finder
        @storefront_credit_card_finder = Spree::Dependencies.credit_card_finder
        @storefront_find_by_variant_finder = Spree::Dependencies.line_item_by_variant_finder
        @storefront_products_finder = Spree::Dependencies.products_finder
        @storefront_taxon_finder = Spree::Dependencies.taxon_finder

        @error_handler = 'Spree::Api::ErrorHandler'
      end

      def set_platform_defaults
        # serializers
        @platform_admin_user_serializer = 'Spree::Api::V2::Platform::UserSerializer'

        # coupon code handler
        @platform_coupon_handler = Spree::Dependencies.coupon_handler

        # order services
        @platform_order_recalculate_service = Spree::Dependencies.cart_recalculate_service
        @platform_order_update_service = Spree::Dependencies.checkout_update_service
        @platform_order_empty_service = Spree::Dependencies.cart_empty_service
        @platform_order_destroy_service = Spree::Dependencies.cart_destroy_service
        @platform_order_next_service = Spree::Dependencies.checkout_next_service
        @platform_order_advance_service = Spree::Dependencies.checkout_advance_service
        @platform_order_complete_service = Spree::Dependencies.checkout_complete_service
        @platform_order_use_store_credit_service = Spree::Dependencies.checkout_add_store_credit_service
        @platform_order_remove_store_credit_service = Spree::Dependencies.checkout_remove_store_credit_service
        @platform_order_approve_service = Spree::Dependencies.order_approve_service
        @platform_order_cancel_service = Spree::Dependencies.order_cancel_service

        # line item services
        @platform_line_item_create_service = Spree::Dependencies.line_item_create_service
        @platform_line_item_update_service = Spree::Dependencies.line_item_update_service
        @platform_line_item_destroy_service = Spree::Dependencies.line_item_destroy_service

        # shipment services
        @platform_shipment_create_service = Spree::Dependencies.shipment_create_service
        @platform_shipment_update_service = Spree::Dependencies.shipment_update_service
        @platform_shipment_change_state_service = Spree::Dependencies.shipment_change_state_service
        @platform_shipment_add_item_service = Spree::Dependencies.shipment_add_item_service
        @platform_shipment_remove_item_service = Spree::Dependencies.shipment_remove_item_service
      end
    end
  end
end
