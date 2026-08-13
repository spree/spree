require_relative 'dependencies_helper'

module Spree
  module Core
    class Dependencies
      INJECTION_POINTS_WITH_DEFAULTS = {
        # ability (staff / back-office authorization)
        ability_class: 'Spree::Ability',

        # storefront record access (ownership + guest tokens); the B2B seam —
        # see Spree::Storefront::AccessPolicy
        storefront_access_policy_class: 'Spree::Storefront::AccessPolicy',

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
        cart_merge_workflow: 'Spree::Carts::Merge',

        # checkout
        checkout_advance_service: 'Spree::Checkout::Advance',
        checkout_add_store_credit_service: 'Spree::Checkout::AddStoreCredit',
        checkout_remove_store_credit_service: 'Spree::Checkout::RemoveStoreCredit',

        # gift cards
        gift_card_apply_service: 'Spree::GiftCards::Apply',
        gift_card_remove_service: 'Spree::GiftCards::Remove',
        gift_card_redeem_service: 'Spree::GiftCards::Redeem',

        # order
        order_approve_service: 'Spree::Orders::Approve',
        order_cancel_workflow: 'Spree::Orders::Cancel',
        order_resume_workflow: 'Spree::Orders::Resume',
        order_complete_workflow: 'Spree::Orders::Complete',
        order_discount_create_service: 'Spree::Orders::Discounts::Create',
        order_discount_update_service: 'Spree::Orders::Discounts::Update',
        order_discount_destroy_service: 'Spree::Orders::Discounts::Destroy',
        order_fee_create_service: 'Spree::Orders::Fees::Create',
        order_fee_update_service: 'Spree::Orders::Fees::Update',
        order_fee_destroy_service: 'Spree::Orders::Fees::Destroy',
        order_create_service: 'Spree::Orders::Create',
        order_update_service: 'Spree::Orders::Update',
        order_update_statuses_service: 'Spree::Orders::UpdateStatuses',
        order_updater: 'Spree::OrderUpdater',

        # fulfillment
        fulfillment_create_workflow: 'Spree::Fulfillments::Create',
        fulfillment_update_workflow: 'Spree::Fulfillments::Update',
        fulfillment_fulfill_workflow: 'Spree::Fulfillments::Fulfill',
        fulfillment_cancel_workflow: 'Spree::Fulfillments::Cancel',
        fulfillment_resume_workflow: 'Spree::Fulfillments::Resume',
        fulfillment_mark_delivered_workflow: 'Spree::Fulfillments::MarkDelivered',
        fulfillment_purchase_label_workflow: 'Spree::Fulfillments::PurchaseLabel',
        fulfillment_update_tracking_workflow: 'Spree::Fulfillments::UpdateTracking',

        # returns
        return_create_workflow: 'Spree::Returns::Create',
        return_approve_workflow: 'Spree::Returns::Approve',
        return_receive_workflow: 'Spree::Returns::Receive',
        return_refund_workflow: 'Spree::Returns::Refund',
        return_cancel_workflow: 'Spree::Returns::Cancel',

        # exchanges
        exchange_create_workflow: 'Spree::Exchanges::Create',
        exchange_approve_workflow: 'Spree::Exchanges::Approve',
        exchange_receive_workflow: 'Spree::Exchanges::Receive',
        exchange_fulfill_workflow: 'Spree::Exchanges::Fulfill',
        exchange_cancel_workflow: 'Spree::Exchanges::Cancel',

        # claims
        claim_create_workflow: 'Spree::Claims::Create',
        claim_approve_workflow: 'Spree::Claims::Approve',
        claim_resolve_workflow: 'Spree::Claims::Resolve',
        claim_deny_workflow: 'Spree::Claims::Deny',
        claim_cancel_workflow: 'Spree::Claims::Cancel',

        tax_exemption_certificate_verify_workflow: 'Spree::TaxExemptionCertificates::Verify',

        # customers
        customer_create_workflow: 'Spree::Customers::Create',

        # tracking numbers
        tracking_number_service: 'Spree::TrackingNumbers::BaseService',

        # coupons
        # TODO: we should split this service into 2 separate - Add and Remove
        coupon_handler: 'Spree::PromotionHandler::Coupon',

        # addresses
        address_create_service: 'Spree::Addresses::Create',
        address_update_service: 'Spree::Addresses::Update',

        payment_create_service: 'Spree::Payments::Create',
        payment_capture_workflow: 'Spree::Payments::Capture',
        payment_refund_workflow: 'Spree::Payments::Refund',
        payments_handle_webhook_workflow: 'Spree::Payments::HandleWebhook',

        # finders
        current_store_finder: 'Spree::Stores::FindDefault',
        line_item_by_variant_finder: 'Spree::LineItems::FindByVariant',

        # search — the document shape belongs to whichever indexing provider is
        # installed (spree_meilisearch registers its own), so core ships no default.
        search_product_presenter: nil,

        # tax — assembles the exemption evidence handed to the tax provider.
        # Core resolves none; swap this to read wherever certificates live.
        tax_resolve_exemptions_service: 'Spree::Tax::ResolveExemptions'
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
        cart_merge_strategy: :cart_merge_workflow,
        carts_complete_service: :carts_complete_workflow,
        payments_handle_webhook_service: :payments_handle_webhook_workflow,
        fulfillment_create_service: :fulfillment_create_workflow,
        order_cancel_service: :order_cancel_workflow,
        order_complete_service: :order_complete_workflow
      }.freeze

      # Same stash-don't-apply treatment for the 6.0 Shipment→Fulfillment
      # service rename: the new class speaks the fulfillment keyword
      # vocabulary (still accepting the old shipment keywords with a
      # warning), but a legacy override written against the old keywords is
      # not interchangeable with what the new call sites pass. Removed in 6.1.
      LEGACY_SERVICE_KEYS = {
        shipment_update_service: :fulfillment_update_workflow,
        fulfillment_update_service: :fulfillment_update_workflow
      }.freeze

      def legacy_workflow_overrides
        @legacy_workflow_overrides ||= {}
      end

      LEGACY_WORKFLOW_KEYS.merge(LEGACY_SERVICE_KEYS).each do |legacy, current|
        define_method("#{legacy}=") do |value|
          Spree::Deprecation.warn(
            "Spree::Dependencies##{legacy}= is deprecated and NO LONGER CONSULTED by Spree — " \
            "the override was not applied. Port the class to the #{current} contract and " \
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
