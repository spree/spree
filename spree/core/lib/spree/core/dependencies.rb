require_relative 'dependencies_helper'

module Spree
  module Core
    class Dependencies
      INJECTION_POINTS_WITH_DEFAULTS = {
        # ability
        ability_class: 'Spree::Ability',

        # cart
        cart_compare_line_items_service: 'Spree::CompareLineItems',
        cart_add_item_service: 'Spree::Cart::AddItem',
        cart_update_service: 'Spree::Cart::Update',
        cart_recalculate_service: 'Spree::Cart::Recalculate',
        cart_remove_item_service: 'Spree::Cart::RemoveItem',
        cart_remove_line_item_service: 'Spree::Cart::RemoveLineItem',
        cart_set_item_quantity_service: 'Spree::Cart::SetQuantity',
        cart_empty_service: 'Spree::Cart::Empty',
        cart_destroy_service: 'Spree::Cart::Destroy',
        cart_associate_service: 'Spree::Cart::Associate',
        cart_remove_out_of_stock_items_service: 'Spree::Cart::RemoveOutOfStockItems',

        # carts
        carts_complete_service: 'Spree::Carts::Complete',

        # checkout
        checkout_next_service: 'Spree::Checkout::Next',
        checkout_advance_service: 'Spree::Checkout::Advance',
        checkout_add_store_credit_service: 'Spree::Checkout::AddStoreCredit',
        checkout_remove_store_credit_service: 'Spree::Checkout::RemoveStoreCredit',
        checkout_select_shipping_method_service: 'Spree::Checkout::SelectShippingMethod',

        # gift cards
        gift_card_apply_service: 'Spree::GiftCards::Apply',
        gift_card_remove_service: 'Spree::GiftCards::Remove',
        gift_card_redeem_service: 'Spree::GiftCards::Redeem',

        # order
        order_approve_service: 'Spree::Orders::Approve',
        order_cancel_service: 'Spree::Orders::Cancel',
        order_updater: 'Spree::OrderUpdater',

        # shipment
        shipment_update_service: 'Spree::Shipments::Update',

        # tracking numbers
        tracking_number_service: 'Spree::TrackingNumbers::BaseService',

        # sorter
        collection_sorter: 'Spree::BaseSorter',

        # coupons
        # TODO: we should split this service into 2 separate - Add and Remove
        coupon_handler: 'Spree::PromotionHandler::Coupon',

        # addresses
        address_create_service: 'Spree::Addresses::Create',
        address_update_service: 'Spree::Addresses::Update',

        # credit cards
        credit_cards_destroy_service: 'Spree::CreditCards::Destroy',

        # line items
        line_item_create_service: 'Spree::LineItems::Create',
        line_item_update_service: 'Spree::LineItems::Update',
        line_item_destroy_service: 'Spree::LineItems::Destroy',

        payments_handle_webhook_service: 'Spree::Payments::HandleWebhook',

        # finders
        current_store_finder: 'Spree::Stores::FindDefault',
        line_item_by_variant_finder: 'Spree::LineItems::FindByVariant',

        # search
        search_product_presenter: 'Spree::SearchProvider::ProductPresenter'
      }.freeze

      include Spree::DependenciesHelper
    end
  end
end
