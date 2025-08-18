require 'spree/core/dependencies_helper'

module Spree
  module Api
    class ApiDependencies
      INJECTION_POINTS_WITH_DEFAULTS = {
        # cart services
        storefront_cart_create_service: -> { Spree::Dependencies.cart_create_service },
        storefront_cart_add_item_service: -> { Spree::Dependencies.cart_add_item_service },
        storefront_cart_compare_line_items_service: -> { Spree::Dependencies.cart_compare_line_items_service },
        storefront_cart_update_service: -> { Spree::Dependencies.cart_update_service },
        storefront_cart_remove_line_item_service: -> { Spree::Dependencies.cart_remove_line_item_service },
        storefront_cart_remove_item_service: -> { Spree::Dependencies.cart_remove_item_service },
        storefront_cart_set_item_quantity_service: -> { Spree::Dependencies.cart_set_item_quantity_service },
        storefront_cart_recalculate_service: -> { Spree::Dependencies.cart_recalculate_service },
        storefront_cart_estimate_shipping_rates_service: -> { Spree::Dependencies.cart_estimate_shipping_rates_service },
        storefront_cart_empty_service: -> { Spree::Dependencies.cart_empty_service },
        storefront_cart_destroy_service: -> { Spree::Dependencies.cart_destroy_service },
        storefront_cart_associate_service: -> { Spree::Dependencies.cart_associate_service },
        storefront_cart_change_currency_service: -> { Spree::Dependencies.cart_change_currency_service },

        # coupon code handler
        storefront_coupon_handler: -> { Spree::Dependencies.coupon_handler },

        # checkout services
        storefront_checkout_next_service: -> { Spree::Dependencies.checkout_next_service },
        storefront_checkout_advance_service: -> { Spree::Dependencies.checkout_advance_service },
        storefront_checkout_update_service: -> { Spree::Dependencies.checkout_update_service },
        storefront_checkout_complete_service: -> { Spree::Dependencies.checkout_complete_service },
        storefront_checkout_add_store_credit_service: -> { Spree::Dependencies.checkout_add_store_credit_service },
        storefront_checkout_remove_store_credit_service: -> { Spree::Dependencies.checkout_remove_store_credit_service },
        storefront_checkout_get_shipping_rates_service: -> { Spree::Dependencies.checkout_get_shipping_rates_service },
        storefront_checkout_select_shipping_method_service: -> { Spree::Dependencies.checkout_select_shipping_method_service },

        # gift cards
        storefront_gift_card_apply_service: -> { Spree::Dependencies.gift_card_apply_service },
        storefront_gift_card_remove_service: -> { Spree::Dependencies.gift_card_remove_service },

        # account services
        storefront_account_create_service: -> { Spree::Dependencies.account_create_service },
        storefront_account_update_service: -> { Spree::Dependencies.account_update_service },

        # address services
        storefront_address_create_service: -> { Spree::Dependencies.address_create_service },
        storefront_address_update_service: -> { Spree::Dependencies.address_update_service },

        # credit card services
        storefront_credit_cards_destroy_service: -> { Spree::Dependencies.credit_cards_destroy_service },

        # payment services
        storefront_payment_create_service: -> { Spree::Dependencies.payment_create_service },

        # serializers
        storefront_address_serializer: 'Spree::V2::Storefront::AddressSerializer',
        storefront_cart_serializer: 'Spree::V2::Storefront::CartSerializer',
        storefront_cms_page_serializer: 'Spree::V2::Storefront::CmsPageSerializer', # LEGACY
        storefront_credit_card_serializer: 'Spree::V2::Storefront::CreditCardSerializer',
        storefront_country_serializer: 'Spree::V2::Storefront::CountrySerializer',
        storefront_menu_serializer: 'Spree::V2::Storefront::MenuSerializer', # LEGACY
        storefront_user_serializer: 'Spree::V2::Storefront::UserSerializer',
        storefront_shipment_serializer: 'Spree::V2::Storefront::ShipmentSerializer',
        storefront_taxon_serializer: 'Spree::V2::Storefront::TaxonSerializer',
        storefront_payment_method_serializer: 'Spree::V2::Storefront::PaymentMethodSerializer',
        storefront_payment_serializer: 'Spree::V2::Storefront::PaymentSerializer',
        storefront_product_serializer: 'Spree::V2::Storefront::ProductSerializer',
        storefront_estimated_shipment_serializer: 'Spree::V2::Storefront::EstimatedShippingRateSerializer',
        storefront_store_serializer: 'Spree::V2::Storefront::StoreSerializer',
        storefront_policy_serializer: 'Spree::V2::Storefront::PolicySerializer',
        storefront_order_serializer: 'Spree::V2::Storefront::OrderSerializer',
        storefront_variant_serializer: 'Spree::V2::Storefront::VariantSerializer',

        # sorters
        storefront_collection_sorter: -> { Spree::Dependencies.collection_sorter },
        storefront_order_sorter: -> { Spree::Dependencies.collection_sorter },
        storefront_products_sorter: -> { Spree::Dependencies.products_sorter },
        platform_products_sorter: -> { Spree::Dependencies.products_sorter },

        # paginators
        storefront_collection_paginator: -> { Spree::Dependencies.collection_paginator },

        # finders
        storefront_address_finder: -> { Spree::Dependencies.address_finder },
        storefront_country_finder: -> { Spree::Dependencies.country_finder },
        storefront_cms_page_finder: -> { Spree::Dependencies.cms_page_finder },
        storefront_menu_finder: -> { Spree::Dependencies.menu_finder },
        storefront_current_order_finder: -> { Spree::Dependencies.current_order_finder },
        storefront_completed_order_finder: -> { Spree::Dependencies.completed_order_finder },
        storefront_credit_card_finder: -> { Spree::Dependencies.credit_card_finder },
        storefront_find_by_variant_finder: -> { Spree::Dependencies.line_item_by_variant_finder },
        storefront_products_finder: -> { Spree::Dependencies.products_finder },
        storefront_taxon_finder: -> { Spree::Dependencies.taxon_finder },
        storefront_variant_finder: -> { Spree::Dependencies.variant_finder },

        # serializers
        platform_address_serializer: 'Spree::Api::V2::Platform::AddressSerializer',
        platform_adjustment_serializer: 'Spree::Api::V2::Platform::AdjustmentSerializer',
        platform_admin_user_serializer: 'Spree::Api::V2::Platform::AdminUserSerializer',
        platform_asset_serializer: 'Spree::Api::V2::Platform::AssetSerializer',
        platform_calculator_serializer: 'Spree::Api::V2::Platform::CalculatorSerializer',
        platform_classification_serializer: 'Spree::Api::V2::Platform::ClassificationSerializer',
        platform_country_serializer: 'Spree::Api::V2::Platform::CountrySerializer',
        platform_credit_card_serializer: 'Spree::Api::V2::Platform::CreditCardSerializer',
        platform_customer_return_serializer: 'Spree::Api::V2::Platform::CustomerReturnSerializer',
        platform_data_feed_serializer: 'Spree::Api::V2::Platform::DataFeedSerializer',
        platform_digital_link_serializer: 'Spree::Api::V2::Platform::DigitalLinkSerializer',
        platform_digital_serializer: 'Spree::Api::V2::Platform::DigitalSerializer',
        platform_gift_card_serializer: 'Spree::Api::V2::Platform::GiftCardSerializer',
        platform_image_serializer: 'Spree::Api::V2::Platform::ImageSerializer',
        platform_inventory_unit_serializer: 'Spree::Api::V2::Platform::InventoryUnitSerializer',
        platform_line_item_serializer: 'Spree::Api::V2::Platform::LineItemSerializer',
        platform_log_entry_serializer: 'Spree::Api::V2::Platform::LogEntrySerializer',
        platform_option_type_serializer: 'Spree::Api::V2::Platform::OptionTypeSerializer',
        platform_option_value_serializer: 'Spree::Api::V2::Platform::OptionValueSerializer',
        platform_order_promotion_serializer: 'Spree::Api::V2::Platform::OrderPromotionSerializer',
        platform_order_serializer: 'Spree::Api::V2::Platform::OrderSerializer',
        platform_payment_capture_event_serializer: 'Spree::Api::V2::Platform::PaymentCaptureEventSerializer',
        platform_payment_method_serializer: 'Spree::Api::V2::Platform::PaymentMethodSerializer',
        platform_payment_serializer: 'Spree::Api::V2::Platform::PaymentSerializer',
        platform_payment_source_serializer: 'Spree::Api::V2::Platform::PaymentSourceSerializer',
        platform_price_serializer: 'Spree::Api::V2::Platform::PriceSerializer',
        platform_product_property_serializer: 'Spree::Api::V2::Platform::ProductPropertySerializer',
        platform_product_serializer: 'Spree::Api::V2::Platform::ProductSerializer',
        platform_promotion_action_line_item_serializer: 'Spree::Api::V2::Platform::PromotionActionLineItemSerializer',
        platform_promotion_action_serializer: 'Spree::Api::V2::Platform::PromotionActionSerializer',
        platform_promotion_category_serializer: 'Spree::Api::V2::Platform::PromotionCategorySerializer',
        platform_promotion_rule_serializer: 'Spree::Api::V2::Platform::PromotionRuleSerializer',
        platform_promotion_serializer: 'Spree::Api::V2::Platform::PromotionSerializer',
        platform_property_serializer: 'Spree::Api::V2::Platform::PropertySerializer',
        platform_prototype_serializer: 'Spree::Api::V2::Platform::PrototypeSerializer',
        platform_refund_reason_serializer: 'Spree::Api::V2::Platform::RefundReasonSerializer',
        platform_refund_serializer: 'Spree::Api::V2::Platform::RefundSerializer',
        platform_reimbursement_credit_serializer: 'Spree::Api::V2::Platform::ReimbursementCreditSerializer',
        platform_reimbursement_serializer: 'Spree::Api::V2::Platform::ReimbursementSerializer',
        platform_reimbursement_type_serializer: 'Spree::Api::V2::Platform::ReimbursementTypeSerializer',
        platform_return_authorization_reason_serializer: 'Spree::Api::V2::Platform::ReturnAuthorizationReasonSerializer',
        platform_return_authorization_serializer: 'Spree::Api::V2::Platform::ReturnAuthorizationSerializer',
        platform_return_item_serializer: 'Spree::Api::V2::Platform::ReturnItemSerializer',
        platform_role_serializer: 'Spree::Api::V2::Platform::RoleSerializer',
        platform_shipment_serializer: 'Spree::Api::V2::Platform::ShipmentSerializer',
        platform_shipping_category_serializer: 'Spree::Api::V2::Platform::ShippingCategorySerializer',
        platform_shipping_method_serializer: 'Spree::Api::V2::Platform::ShippingMethodSerializer',
        platform_shipping_rate_serializer: 'Spree::Api::V2::Platform::ShippingRateSerializer',
        platform_state_change_serializer: 'Spree::Api::V2::Platform::StateChangeSerializer',
        platform_state_serializer: 'Spree::Api::V2::Platform::StateSerializer',
        platform_stock_item_serializer: 'Spree::Api::V2::Platform::StockItemSerializer',
        platform_stock_location_serializer: 'Spree::Api::V2::Platform::StockLocationSerializer',
        platform_stock_movement_serializer: 'Spree::Api::V2::Platform::StockMovementSerializer',
        platform_stock_transfer_serializer: 'Spree::Api::V2::Platform::StockTransferSerializer',
        platform_store_credit_category_serializer: 'Spree::Api::V2::Platform::StoreCreditCategorySerializer',
        platform_store_credit_event_serializer: 'Spree::Api::V2::Platform::StoreCreditEventSerializer',
        platform_store_credit_serializer: 'Spree::Api::V2::Platform::StoreCreditSerializer',
        platform_store_credit_type_serializer: 'Spree::Api::V2::Platform::StoreCreditTypeSerializer',
        platform_store_serializer: 'Spree::Api::V2::Platform::StoreSerializer',
        platform_tax_category_serializer: 'Spree::Api::V2::Platform::TaxCategorySerializer',
        platform_tax_rate_serializer: 'Spree::Api::V2::Platform::TaxRateSerializer',
        platform_taxon_image_serializer: 'Spree::Api::V2::Platform::TaxonImageSerializer',
        platform_taxon_serializer: 'Spree::Api::V2::Platform::TaxonSerializer',
        platform_taxonomy_serializer: 'Spree::Api::V2::Platform::TaxonomySerializer',
        platform_user_serializer: 'Spree::Api::V2::Platform::UserSerializer',
        platform_variant_serializer: 'Spree::Api::V2::Platform::VariantSerializer',
        platform_webhooks_event_serializer: 'Spree::Api::V2::Platform::Webhooks::EventSerializer',
        platform_webhooks_subscriber_serializer: 'Spree::Api::V2::Platform::Webhooks::SubscriberSerializer',
        platform_wished_item_serializer: 'Spree::Api::V2::Platform::WishedItemSerializer',
        platform_wishlist_serializer: 'Spree::Api::V2::Platform::WishlistSerializer',
        platform_zone_member_serializer: 'Spree::Api::V2::Platform::ZoneMemberSerializer',
        platform_zone_serializer: 'Spree::Api::V2::Platform::ZoneSerializer',

        # coupon code handler
        platform_coupon_handler: -> { Spree::Dependencies.coupon_handler },

        # order services
        platform_order_recalculate_service: -> { Spree::Dependencies.cart_recalculate_service },
        platform_order_update_service: -> { Spree::Dependencies.checkout_update_service },
        platform_order_empty_service: -> { Spree::Dependencies.cart_empty_service },
        platform_order_destroy_service: -> { Spree::Dependencies.cart_destroy_service },
        platform_order_next_service: -> { Spree::Dependencies.checkout_next_service },
        platform_order_advance_service: -> { Spree::Dependencies.checkout_advance_service },
        platform_order_complete_service: -> { Spree::Dependencies.checkout_complete_service },
        platform_order_use_store_credit_service: -> { Spree::Dependencies.checkout_add_store_credit_service },
        platform_order_remove_store_credit_service: -> { Spree::Dependencies.checkout_remove_store_credit_service },
        platform_order_approve_service: -> { Spree::Dependencies.order_approve_service },
        platform_order_cancel_service: -> { Spree::Dependencies.order_cancel_service },

        # line item services
        platform_line_item_create_service: -> { Spree::Dependencies.line_item_create_service },
        platform_line_item_update_service: -> { Spree::Dependencies.line_item_update_service },
        platform_line_item_destroy_service: -> { Spree::Dependencies.line_item_destroy_service },

        # shipment services
        platform_shipment_create_service: -> { Spree::Dependencies.shipment_create_service },
        platform_shipment_update_service: -> { Spree::Dependencies.shipment_update_service },
        platform_shipment_change_state_service: -> { Spree::Dependencies.shipment_change_state_service },
        platform_shipment_add_item_service: -> { Spree::Dependencies.shipment_add_item_service },
        platform_shipment_remove_item_service: -> { Spree::Dependencies.shipment_remove_item_service },
      }

      include Spree::DependenciesHelper
    end
  end
end
