require 'spree/core/dependencies_helper'

module Spree
  module Api
    class ApiDependencies
      # Serializers named after their key: `product_serializer` is
      # Spree::Api::V3::ProductSerializer, `admin_product_serializer` its Admin
      # twin and `seller_product_serializer` its Seller one.
      STORE_SERIALIZERS =
        %i[credit_card price price_history product product_type variant media option_type option_value cart order
           order_group line_item payment payment_session payment_setup_session payment_source store_credit
           fulfillment delivery address customer data_request customer_group country channel product_publication
           market state wishlist wishlist_item payment_method delivery_method delivery_rate freight_summary
           stock_location category collection applied_promotion discount tax_line delivery_zone delivery_zone_member
           fee digital_link gift_card currency locale policy custom_field tax_category tax_identifier
           product_filters product_filter_price_range product_filter_availability product_filter_availability_option
           product_filter_option product_filter_option_value product_filter_category product_filter_category_option
           product_filter_sort_option media_event return return_line_item exchange exchange_line_item claim
           claim_line_item return_reason claim_reason digital_asset export gift_card_batch import import_row
           invitation newsletter_subscriber promotion refund stock_level stock_movement stock_reservation
           stock_transfer company company_membership company_invitation seller].freeze

      ADMIN_SERIALIZERS =
        %i[country state applied_promotion discount tax_line cart delivery_zone delivery_profile
           delivery_origin_group integration delivery_method_rule delivery_zone_member fee consent_record customer
           data_request newsletter_subscriber order order_group product product_type
           product_type_custom_field_definition variant price price_history custom_field custom_field_definition
           category collection collection_rule line_item option_type option_value media stock_level stock_movement
           stock_transfer stock_transfer_item supplier purchase_order purchase_order_item stock_receipt
           stock_receipt_item fulfillment fulfillment_item delivery shipping_label gift_card gift_card_batch payment
           refund return_reason claim_reason refund_reason order_cancellation_reason return return_line_item
           exchange exchange_line_item claim claim_line_item package_type policy tax_category tax_rate
           tax_identifier company company_membership company_invitation catalog catalog_price catalog_price_tier
           catalog_product price_list_product catalog_assignment catalog_quantity_rule catalog_product_term
           catalog_order_minimum tax_exemption_certificate admin_user actor seller_team_member product_submission
           seller seller_requirement seller_requirement_submission seller_requirement_status commission_rate
           commission_rule commission_line seller_transfer seller_payout seller_balance payment_split address
           channel order_routing_rule product_publication market delivery_method delivery_method_service
           stock_location stock_reservation delivery_rate freight_summary freight_summary_line payment_method
           credit_card store_credit store_credit_event customer_group payment_source digital_asset digital_link
           store setup_task api_key allowed_origin webhook_endpoint webhook_event webhook_delivery invitation
           invitation_acceptance_link role permission export saved_report import import_row import_mapping promotion
           promotion_action promotion_rule coupon_code price_adjustment_tier price_list price_rule
           resource_translations email_template email_template_draft email_template_revision email_template_preview
           email_template_sample_record].freeze

      SELLER_SERIALIZERS =
        %i[profile policy team_member account invitation invitation_acceptance_link product product_type
           delivery_profile delivery_method delivery_method_rule delivery_zone variant media stock_level order
           order_line_item fulfillment fulfillment_item delivery delivery_rate shipping_label return
           return_line_item exchange exchange_line_item claim claim_line_item reason package_type stock_location
           requirement_custom_field tax_identifier requirement_status import import_row import_mapping
           requirement_submission export transfer payout balance payment_split].freeze

      INJECTION_POINTS_WITH_DEFAULTS = {
        **STORE_SERIALIZERS.to_h { |name| [:"#{name}_serializer", "Spree::Api::V3::#{name.to_s.camelize}Serializer"] },
        **ADMIN_SERIALIZERS.to_h { |name| [:"admin_#{name}_serializer", "Spree::Api::V3::Admin::#{name.to_s.camelize}Serializer"] },
        **SELLER_SERIALIZERS.to_h { |name| [:"seller_#{name}_serializer", "Spree::Api::V3::Seller::#{name.to_s.camelize}Serializer"] },
        shipment_serializer: 'Spree::Api::V3::FulfillmentSerializer',
        wished_item_serializer: 'Spree::Api::V3::WishlistItemSerializer',
        shipping_method_serializer: 'Spree::Api::V3::DeliveryMethodSerializer',
        shipping_rate_serializer: 'Spree::Api::V3::DeliveryRateSerializer',
        admin_shipment_serializer: 'Spree::Api::V3::Admin::FulfillmentSerializer',
        product_submission_serializer: 'Spree::Api::V3::Seller::ProductSubmissionSerializer',
        admin_shipping_method_serializer: 'Spree::Api::V3::Admin::DeliveryMethodSerializer',
        admin_shipping_rate_serializer: 'Spree::Api::V3::Admin::DeliveryRateSerializer'
      }

      include Spree::DependenciesHelper

      # Pre-6.0 names for the StockItem → StockLevel serializers. Unlike the
      # legacy workflow keys in core, these forward instead of stashing: a
      # serializer renders the same model under a new class name, so an
      # override written against the old key is still the class the host app
      # wants used. Removed in 6.1.
      LEGACY_SERIALIZER_KEYS = {
        stock_item_serializer: :stock_level_serializer,
        admin_stock_item_serializer: :admin_stock_level_serializer,
        digital_serializer: :digital_asset_serializer,
        admin_digital_serializer: :admin_digital_asset_serializer
      }.freeze

      LEGACY_SERIALIZER_KEYS.each do |legacy, current|
        define_method("#{legacy}=") do |value|
          Spree::Deprecation.warn("Spree.api.#{legacy}= is deprecated and will be removed in Spree 6.1. Use #{current}= instead.")
          send("#{current}=", value)
        end

        define_method(legacy) do
          Spree::Deprecation.warn("Spree.api.#{legacy} is deprecated and will be removed in Spree 6.1. Use #{current} instead.")
          send(current)
        end

        define_method("#{legacy}_class") do
          Spree::Deprecation.warn("Spree.api.#{legacy}_class is deprecated and will be removed in Spree 6.1. Use #{current}_class instead.")
          send("#{current}_class")
        end
      end
    end
  end
end
