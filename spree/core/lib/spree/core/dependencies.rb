require_relative 'dependencies_helper'

module Spree
  module Core
    class Dependencies
      INJECTION_POINTS_WITH_DEFAULTS = {
        # ability
        ability_class: 'Spree::Ability',

        # cart
        cart_compare_line_items_service: 'Spree::CompareLineItems',
        cart_create_service: 'Spree::Cart::Create',
        cart_add_item_service: 'Spree::Cart::AddItem',
        cart_update_service: 'Spree::Cart::Update',
        cart_recalculate_service: 'Spree::Cart::Recalculate',
        cart_remove_item_service: 'Spree::Cart::RemoveItem',
        cart_remove_line_item_service: 'Spree::Cart::RemoveLineItem',
        cart_set_item_quantity_service: 'Spree::Cart::SetQuantity',
        cart_estimate_shipping_rates_service: 'Spree::Cart::EstimateShippingRates',
        cart_empty_service: 'Spree::Cart::Empty',
        cart_destroy_service: 'Spree::Cart::Destroy',
        cart_associate_service: 'Spree::Cart::Associate',
        cart_change_currency_service: 'Spree::Cart::ChangeCurrency',
        cart_remove_out_of_stock_items_service: 'Spree::Cart::RemoveOutOfStockItems',

        # checkout
        checkout_next_service: 'Spree::Checkout::Next',
        checkout_advance_service: 'Spree::Checkout::Advance',
        checkout_update_service: 'Spree::Checkout::Update',
        checkout_complete_service: 'Spree::Checkout::Complete',
        checkout_add_store_credit_service: 'Spree::Checkout::AddStoreCredit',
        checkout_remove_store_credit_service: 'Spree::Checkout::RemoveStoreCredit',
        checkout_get_shipping_rates_service: 'Spree::Checkout::GetShippingRates',
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
        shipment_change_state_service: 'Spree::Shipments::ChangeState',
        shipment_create_service: 'Spree::Shipments::Create',
        shipment_update_service: 'Spree::Shipments::Update',
        shipment_add_item_service: 'Spree::Shipments::AddItem',
        shipment_remove_item_service: 'Spree::Shipments::RemoveItem',

        # tracking numbers
        tracking_number_service: 'Spree::TrackingNumbers::BaseService',

        # sorter
        collection_sorter: 'Spree::BaseSorter',
        order_sorter: 'Spree::BaseSorter',
        posts_sorter: nil,
        products_sorter: 'Spree::Products::Sort',
        # paginator
        collection_paginator: 'Spree::Shared::Paginate',

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
        classification_reposition_service: 'Spree::Classifications::Reposition',

        # line items
        line_item_create_service: 'Spree::LineItems::Create',
        line_item_update_service: 'Spree::LineItems::Update',
        line_item_destroy_service: 'Spree::LineItems::Destroy',

        payment_create_service: 'Spree::Payments::Create',

        # data feeds
        data_feeds_google_rss_service: 'Spree::DataFeeds::Google::Rss',
        data_feeds_google_optional_attributes_service: 'Spree::DataFeeds::Google::OptionalAttributes',
        data_feeds_google_required_attributes_service: 'Spree::DataFeeds::Google::RequiredAttributes',
        data_feeds_google_optional_sub_attributes_service: 'Spree::DataFeeds::Google::OptionalSubAttributes',
        data_feeds_google_products_list: 'Spree::DataFeeds::Google::ProductsList',

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
        variant_finder: 'Spree::Variants::Find'
      }.freeze

      include Spree::DependenciesHelper
    end
  end
end
