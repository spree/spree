module Spree
  class ApiDependencies < Preferences::Configuration
    def initialize
      set_storefront_defaults
    end

    def set_storefront_defaults
      # cart services
      @storefront_cart_create_service = Spree::Dependencies.cart_create_service
      @storefront_cart_add_item_service = Spree::Dependencies.cart_add_item_service
      @storefront_cart_remove_item_service = Spree::Dependencies.cart_remove_item_service
      @storefront_cart_set_item_quantity_service = Spree::Dependencies.cart_set_item_quantity_service

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

      # serializers
      @storefront_cart_serializer = Spree::V2::Storefront::CartSerializer
      @storefront_shipment_serializer = Spree::V2::Storefront::ShipmentSerializer
      @storedront_payment_method_serializer = Spree::V2::Storefront::PaymentMethodSerializer

      # finders
      @storefront_current_order_finder = Spree::Dependencies.current_order_finder
    end

    attr_accessor :storefront_cart_create_service, :storefront_cart_add_item_service,
                  :storefront_cart_remove_item_service, :storefront_cart_set_item_quantity_service,
                  :storefront_coupon_handler, :storefront_checkout_next_service, :storefront_checkout_advance_service,
                  :storefront_checkout_update_service, :storefront_checkout_complete_service, :storefront_checkout_add_store_credit_service,
                  :storefront_checkout_remove_store_credit_service, :storefront_checkout_get_shipping_rates_service,
                  :storefront_cart_serializer, :storefront_shipment_serializer, :storedront_payment_method_serializer,
                  :storefront_current_order_finder
  end
end
