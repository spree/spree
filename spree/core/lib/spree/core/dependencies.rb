require_relative 'dependencies_helper'

module Spree
  module Core
    class Dependencies
      INJECTION_POINTS_WITH_DEFAULTS = {
        # ability
        ability_class: 'Spree::Ability',

        # cart — the legacy Spree::Cart::* namespace is gone (Spree::Cart is the
        # cart model since 6.0); surviving services live under Spree::Carts::.
        # cart_create/update/estimate_shipping_rates/change_currency service
        # registrations were removed with their dead implementations.
        cart_compare_line_items_service: 'Spree::CompareLineItems',
        cart_add_item_workflow: 'Spree::Carts::AddItem',
        cart_recalculate_workflow: 'Spree::Carts::Recalculate',
        cart_recalculate_totals_workflow: 'Spree::Carts::RecalculateTotals',
        order_recalculate_totals_workflow: 'Spree::Orders::RecalculateTotals',
        cart_remove_item_service: 'Spree::Carts::RemoveItem',
        cart_remove_line_item_service: 'Spree::Carts::RemoveLineItem',
        cart_set_item_quantity_service: 'Spree::Carts::SetQuantity',

        # draft orders (admin item editing) — cart twins split so the two
        # sides can diverge; see Spree::Orders::AddItem
        order_add_item_service: 'Spree::Orders::AddItem',
        order_update_item_service: 'Spree::Orders::UpdateItem',
        order_remove_line_item_service: 'Spree::Orders::RemoveLineItem',
        order_remove_item_service: 'Spree::Orders::RemoveItem',
        cart_empty_service: 'Spree::Carts::Empty',
        cart_destroy_service: 'Spree::Carts::Destroy',
        cart_associate_service: 'Spree::Carts::Associate',
        cart_remove_out_of_stock_items_service: 'Spree::Carts::RemoveOutOfStockItems',

        # carts
        carts_complete_workflow: 'Spree::Carts::Complete',
        carts_create_service: 'Spree::Carts::Create',
        carts_update_service: 'Spree::Carts::Update',
        carts_upsert_items_service: 'Spree::Carts::UpsertItems',
        carts_validate_service: 'Spree::Carts::Validate',
        cart_merge_strategy: 'Spree::Carts::Merge',

        # checkout
        checkout_next_service: 'Spree::Checkout::Next',
        checkout_advance_service: 'Spree::Checkout::Advance',
        checkout_complete_service: 'Spree::Checkout::Complete',
        checkout_add_store_credit_service: 'Spree::Checkout::AddStoreCredit',
        checkout_remove_store_credit_service: 'Spree::Checkout::RemoveStoreCredit',
        checkout_select_shipping_method_service: 'Spree::Checkout::SelectShippingMethod',

        # gift cards
        gift_card_apply_service: 'Spree::GiftCards::Apply',
        gift_card_remove_service: 'Spree::GiftCards::Remove',
        gift_card_redeem_service: 'Spree::GiftCards::Redeem',

        # order
        order_approve_service: 'Spree::Orders::Approve',
        order_cancel_workflow: 'Spree::Orders::Cancel',
        order_complete_service: 'Spree::Orders::Complete',
        order_add_manual_discount_service: 'Spree::Orders::AddManualDiscount',
        order_create_service: 'Spree::Orders::Create',
        order_update_service: 'Spree::Orders::Update',
        order_updater: 'Spree::OrderUpdater',

        # fulfillment
        fulfillment_create_service: 'Spree::Fulfillments::Create',

        # shipment
        shipment_update_service: 'Spree::Shipments::Update',

        # tracking numbers
        tracking_number_service: 'Spree::TrackingNumbers::BaseService',

        # sorter
        collection_sorter: 'Spree::BaseSorter',
        order_sorter: 'Spree::BaseSorter',
        posts_sorter: nil,
        products_sorter: 'Spree::Products::Sort',
        # paginator
        collection_paginator: nil,

        # coupons
        # TODO: we should split this service into 2 separate - Add and Remove
        coupon_handler: 'Spree::PromotionHandler::Coupon',

        # account
        account_create_service: 'Spree::Account::Create',
        account_update_service: 'Spree::Account::Update',

        # addresses
        address_create_service: 'Spree::Addresses::Create',
        address_update_service: 'Spree::Addresses::Update',

        # credit cards
        credit_cards_destroy_service: 'Spree::CreditCards::Destroy',

        # classifications
        classification_reposition_service: nil,

        # line items

        payment_create_service: 'Spree::Payments::Create',
        payments_handle_webhook_service: 'Spree::Payments::HandleWebhook',

        # finders
        address_finder: 'Spree::Addresses::Find',
        country_finder: 'Spree::Countries::Find',
        cms_page_finder: nil, # LEGACY
        menu_finder: nil, # LEGACY
        current_order_finder: 'Spree::Orders::FindCurrent',
        current_store_finder: 'Spree::Stores::FindDefault',
        completed_order_finder: 'Spree::Orders::FindComplete',
        credit_card_finder: 'Spree::CreditCards::Find',
        posts_finder: nil,
        products_finder: 'Spree::Products::Find',
        taxon_finder: 'Spree::Taxons::Find',
        line_item_by_variant_finder: 'Spree::LineItems::FindByVariant',
        variant_finder: 'Spree::Variants::Find',

        # search
        search_product_presenter: 'Spree::SearchProvider::ProductPresenter'
      }.freeze

      include Spree::DependenciesHelper

      # 6.0 tier rename: these seams resolve Spree::Workflow classes now.
      # The old *_service names stay settable and readable one release so
      # applications don't crash at boot — but a legacy write is stashed,
      # NOT applied to the workflow seam: a class written against the old
      # service contract is not interchangeable with the workflow the new
      # call sites consume. Reads return the stashed value (legacy code
      # calling its own class keeps working), falling back to the workflow
      # class — safe for legacy callers, whose old keyword vocabulary the
      # workflows accept through alias_argument bridges. Removed in 6.1.
      LEGACY_WORKFLOW_KEYS = {
        cart_add_item_service: :cart_add_item_workflow,
        cart_recalculate_service: :cart_recalculate_workflow,
        carts_complete_service: :carts_complete_workflow,
        order_cancel_service: :order_cancel_workflow
      }.freeze

      def legacy_workflow_overrides
        @legacy_workflow_overrides ||= {}
      end

      LEGACY_WORKFLOW_KEYS.each do |legacy, current|
        define_method("#{legacy}=") do |value|
          Spree::Deprecation.warn(
            "Spree::Dependencies##{legacy}= is deprecated and NO LONGER CONSULTED by Spree — " \
            "the override was not applied. Port the class to the Spree::Workflow contract and " \
            "set #{current}= instead. The #{legacy} name is removed in Spree 6.1."
          )
          legacy_workflow_overrides[legacy] = value
        end

        define_method(legacy) do
          Spree::Deprecation.warn("Spree::Dependencies##{legacy} is deprecated and will be removed in Spree 6.1. Use #{current} instead.")
          legacy_workflow_overrides.fetch(legacy) { send(current) }
        end

        define_method("#{legacy}_class") do
          Spree::Deprecation.warn("Spree::Dependencies##{legacy} is deprecated and will be removed in Spree 6.1. Use #{current} instead.")
          if legacy_workflow_overrides.key?(legacy)
            value = legacy_workflow_overrides[legacy]
            value.is_a?(String) ? value.constantize : value
          else
            send("#{current}_class")
          end
        end
      end
    end
  end
end
