module Spree
  class ApiDependencies
    include Spree::DependenciesHelper

    INJECTION_POINTS = [
      ######################
      # Store Front API v2 #
      ######################
      # Cart
      :storefront_cart_create_service, :storefront_cart_add_item_service, :storefront_cart_remove_line_item_service,
      :storefront_cart_remove_item_service, :storefront_cart_set_item_quantity_service, :storefront_cart_recalculate_service,
      :storefront_cart_update, :storefront_cart_compare_line_items_service, :storefront_cart_serializer,
      :storefront_cart_update_service,

      # Coupon
      :storefront_coupon_handler,

      # Checkout
      :storefront_checkout_next_service, :storefront_checkout_advance_service, :storefront_checkout_update_service,
      :storefront_checkout_complete_service, :storefront_checkout_add_store_credit_service, :storefront_checkout_remove_store_credit_service,
      :storefront_checkout_get_shipping_rates_service,

      # Credit Card
      :storefront_credit_card_serializer, :storefront_credit_card_finder,

      # Shipment
      :storefront_shipment_serializer,

      # Payment Method
      :storefront_payment_method_serializer,

      # Country
      :storefront_country_finder, :storefront_country_serializer,

      # Menu
      :storefront_menu_serializer, :storefront_menu_finder,

      # Order
      :storefront_current_order_finder, :storefront_completed_order_finder, :storefront_order_sorter, :storefront_order_serializer,

      # Collection
      :storefront_collection_paginator, :storefront_collection_sorter,

      # User
      :storefront_user_serializer,

      # Products
      :storefront_products_sorter, :storefront_products_finder, :storefront_product_serializer,

      # Taxon
      :storefront_taxon_serializer, :storefront_taxon_finder,

      # Variant
      :storefront_find_by_variant_finder,

      # CMS Pages
      :storefront_cms_page_serializer, :storefront_cms_page_finder,

      # Shipping
      :storefront_cart_estimate_shipping_rates_service, :storefront_estimated_shipment_serializer,

      # Store
      :storefront_store_serializer,

      # Account / Address
      :storefront_address_serializer, :storefront_address_finder, :storefront_account_create_address_service,
      :storefront_account_update_address_service, :storefront_account_create_service, :storefront_account_update_service,

      # Errors
      :error_handler,

      ###################
      # Platform API v2 #
      ###################
      # Order
      :platform_order_create_service, :platform_order_next_service, :platform_order_advance_service, :platform_order_complete_service,
      :platform_order_update_service,

      #
      # Line Item
      :platform_line_item_remove_service, :platform_line_item_add_service, :platform_line_item_set_quantity_service,

      # Coupon
      :platform_coupon_handler
    ].freeze

    attr_accessor(*INJECTION_POINTS)

    def initialize
      set_storefront_defaults
      set_platform_defaults
    end

    private

    def set_platform_defaults
      # Order Services
      @platform_order_create_service = Spree::Dependencies.cart_create_service
      @platform_order_next_service = Spree::Dependencies.checkout_next_service
      @platform_order_advance_service = Spree::Dependencies.checkout_advance_service
      @platform_order_complete_service = Spree::Dependencies.checkout_complete_service
      @platform_order_update_service = Spree::Dependencies.checkout_update_service
      @platform_order_set_item_quantity_service = Spree::Dependencies.cart_set_item_quantity_service

      # Line Item
      @platform_line_item_remove_service = Spree::Dependencies.cart_remove_line_item_service
      @platform_line_item_add_service = Spree::Dependencies.cart_add_item_service
      @platform_line_item_set_quantity_service = Spree::Dependencies.cart_set_item_quantity_service

      # Coupon Code Handler
      @platform_coupon_handler = Spree::Dependencies.coupon_handler
    end

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

      # account services
      @storefront_account_create_service = Spree::Dependencies.account_create_service
      @storefront_account_update_service = Spree::Dependencies.account_update_service
      @storefront_account_create_address_service = Spree::Dependencies.account_create_address_service
      @storefront_account_update_address_service = Spree::Dependencies.account_update_address_service

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
      @storefront_product_serializer = 'Spree::V2::Storefront::ProductSerializer'
      @storefront_estimated_shipment_serializer = 'Spree::V2::Storefront::EstimatedShippingRateSerializer'
      @storefront_store_serializer = 'Spree::V2::Storefront::StoreSerializer'
      @storefront_order_serializer = 'Spree::V2::Storefront::CartSerializer'

      # sorters
      @storefront_collection_sorter = Spree::Dependencies.collection_sorter
      @storefront_order_sorter = Spree::Dependencies.collection_sorter
      @storefront_products_sorter = Spree::Dependencies.products_sorter

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
  end
end
