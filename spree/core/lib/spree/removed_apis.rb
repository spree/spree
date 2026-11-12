module Spree
  # Names the replacement when code calls a Ruby API that Spree removed.
  #
  # Spree is old enough that coding agents, older tutorials and extensions
  # still reach for 4.x and 5.x APIs: the checkout state machine,
  # adjustments, the master variant, return authorizations. Without help,
  # those calls fail with a bare NoMethodError or NameError, and the reader
  # has to work out what replaced them. This module adds one paragraph to
  # those errors naming what to use instead.
  #
  # The hint is added to Exception#detailed_message, the text Ruby, IRB,
  # RSpec and the Rails error page print. The error keeps its class, its
  # #message and its #respond_to? answers, so rescues and duck typing behave
  # exactly as they did. Removed names are never defined, so nothing that
  # still exists can be shadowed.
  #
  # Keys: 'Spree::Order#next' is an instance method, 'Spree::Order.checkout_flow'
  # a class method (also matched when called on a relation), 'Spree::Adjustment'
  # a constant. A key matches subclasses too.
  #
  # When you remove a public Ruby API, add it here (see spree/AGENTS.md).
  module RemovedApis
    UPGRADE_GUIDE_URL = 'https://spreecommerce.org/docs/developer/upgrades/5.6-to-6.0'.freeze

    CHECKOUT = 'Checkout has no state machine. Write cart fields in any order (Spree::Carts::Update, ' \
               'or the Store API cart endpoints), read cart.current_checkout_step and the cart ' \
               'requirements to see what is missing, and place the order with ' \
               'Spree::Dependencies.carts_complete_workflow.constantize.call(cart: cart).'.freeze
    CHECKOUT_CUSTOMIZATION = 'Checkout has no state machine. Add a checkout requirement with ' \
                             'Spree::Checkout::Registry.add_requirement, or a step with Spree::Checkout::Registry.register_step, ' \
                             "and run code at completion with a hook: Spree.hooks.register('carts.complete.before_finalize', ...).".freeze
    ADJUSTMENTS = 'Adjustments are typed rows: tax_lines, discounts and fees.'.freeze
    RETURNS = 'Returns, exchanges and claims are their own records on the order: returns, exchanges, claims.'.freeze
    STATE_CHANGES = 'Status history is no longer stored. Subscribe to events instead (Spree::Subscriber).'.freeze
    PRICE_IN = 'Prices are per currency: price_in(currency).amount or amount_in(currency).'.freeze
    PRIMARY_MEDIA = 'Use primary_media.'.freeze
    SEARCH = 'Use search, or q[search] in the Admin API.'.freeze

    ORDER_AND_CART = {
      'next' => CHECKOUT,
      'next!' => CHECKOUT,
      'state' => 'Orders have status (draft, placed, canceled). Carts have no status: completed_at marks completion, ' \
                 'and current_checkout_step says where checkout stands.',
      'state=' => 'Status changes through workflows, for example Spree::Orders::Cancel. Carts have no status.',
      'can_go_to_state?' => CHECKOUT,
      'restart_checkout_flow' => CHECKOUT,
      'contents' => 'Change cart items with Spree.cart_add_item_workflow or Spree::Dependencies.cart_upsert_items_workflow.',
      'adjustments' => ADJUSTMENTS,
      'all_adjustments' => ADJUSTMENTS,
      'line_item_adjustments' => 'Use line_item_tax_lines and line_item_discounts.',
      'shipment_adjustments' => 'Use fulfillment_tax_lines and fulfillment_discounts.',
      'return_authorizations' => RETURNS,
      'customer_returns' => RETURNS,
      'reimbursements' => RETURNS,
      'state_changes' => STATE_CHANGES
    }.freeze

    ORDER_AND_CART_CLASS = {
      'checkout_flow' => CHECKOUT_CUSTOMIZATION,
      'checkout_steps' => CHECKOUT_CUSTOMIZATION,
      'insert_checkout_step' => CHECKOUT_CUSTOMIZATION,
      'remove_checkout_step' => CHECKOUT_CUSTOMIZATION,
      'remove_transition' => CHECKOUT_CUSTOMIZATION,
      'go_to_state' => CHECKOUT_CUSTOMIZATION,
      'state_machine' => 'Spree 6 has no state machines. Records move between statuses through workflows.',
      'multi_search' => SEARCH
    }.freeze

    VARIANT_AND_PRODUCT = {
      'price' => PRICE_IN,
      'price=' => 'Use set_price(currency, amount).',
      'default_price' => 'Use price_in(currency).',
      'currency' => 'Pass the currency you mean to price_in(currency).',
      'display_price' => 'Use price_in(currency).display_amount.',
      'display_amount' => 'Use price_in(currency).display_amount.',
      'compare_at_price=' => 'Use set_price(currency, amount, compare_at_amount).',
      'display_compare_at_price' => 'Use price_in(currency).display_compare_at_amount.',
      'price_including_vat_for' => 'Use price_in(currency).amount: prices are charged as entered.',
      'has_default_price?' => 'Use prices.base_prices.exists?(currency: currency).',
      'default_image' => PRIMARY_MEDIA,
      'primary_image' => PRIMARY_MEDIA
    }.freeze

    REPLACEMENTS = {
      # Checkout, orders and carts
      **ORDER_AND_CART.flat_map { |name, hint| [["Spree::Order##{name}", hint], ["Spree::Cart##{name}", hint]] }.to_h,
      **ORDER_AND_CART_CLASS.flat_map { |name, hint| [["Spree::Order.#{name}", hint], ["Spree::Cart.#{name}", hint]] }.to_h,
      'Spree::Order::Checkout' => CHECKOUT_CUSTOMIZATION,
      'Spree::OrderContents' => 'Change cart items with Spree.cart_add_item_workflow or Spree::Dependencies.cart_upsert_items_workflow.',
      'Spree::Adjustment' => 'Adjustments are typed rows: Spree::TaxLine, Spree::Discount and Spree::Fee.',
      'Spree::LineItem#adjustments' => ADJUSTMENTS,
      'Spree::Fulfillment#adjustments' => ADJUSTMENTS,
      'Spree::StateChange' => STATE_CHANGES,
      'Spree::LogEntry' => STATE_CHANGES,
      'Spree::Payment#state_changes' => STATE_CHANGES,
      'Spree::Payment#log_entries' => STATE_CHANGES,
      'Spree::Fulfillment#state_changes' => STATE_CHANGES,

      # Returns
      'Spree::ReturnAuthorization' => 'Use Spree::Return, or Spree::Exchange when different items go out.',
      'Spree::CustomerReturn' => 'Use Spree::Return: receiving is a status on the same record.',
      'Spree::Reimbursement' => 'Refund a return with the Spree::Returns::Refund workflow.',
      'Spree::ReimbursementType' => 'Refund a return with the Spree::Returns::Refund workflow.',
      'Spree::ReturnItem' => 'Use Spree::ReturnLineItem, Spree::ExchangeLineItem or Spree::ClaimLineItem.',

      # Catalog and prices
      **VARIANT_AND_PRODUCT.flat_map { |name, hint| [["Spree::Variant##{name}", hint], ["Spree::Product##{name}", hint]] }.to_h,
      'Spree::Product#featured_image' => PRIMARY_MEDIA,
      'Spree::DefaultPrice' => 'Use variant.price_in(currency) and variant.set_price(currency, amount).',
      'Spree::VatPriceCalculation' => 'Use price_in(currency).amount: prices include tax per market.',
      'Spree::Product.with_option' => 'Use with_option_value.',
      'Spree::Product.in_name' => SEARCH,
      'Spree::Product.in_name_or_keywords' => SEARCH,
      'Spree::Product.in_name_or_description' => SEARCH,
      'Spree::Product.with_ids' => 'Use where(id: ids).',
      'Spree::Product.add_search_scope' => 'Declare a plain scope :name, -> { ... }.',
      'Spree::Product.multi_search' => SEARCH,
      'Spree::Variant.multi_search' => SEARCH,
      'Spree::OptionType#color?' => 'Use color_swatch?.',
      'Spree::Category#set_store' => 'Use ensure_store.',
      'Spree::Category.for_taxonomy' => 'Use for_store.',

      # Stores, addresses, users and permissions
      'Spree::Store#admin_users' => 'Use users.',
      'Spree::Store#supported_shipping_zones' => 'Use countries_with_shipping_coverage.',
      'Spree::Address#user_default_billing?' => 'Use is_default_billing?.',
      'Spree::Address#user_default_shipping?' => 'Use is_default_shipping?.',
      'Spree.searcher_class' => 'Use Spree.search_provider.',
      'Spree::PermittedAttributes' => 'Add writable API attributes with Spree::Product.additional_permitted_attributes += [...] ' \
                                      '(any model; always +=).',
      'Spree::Preference' => 'Preferences live on each model in a JSON preferences column.',
      'Spree::User' => 'Use Spree.customer_class for customers and Spree.admin_user_class for staff.',

      # Services and screens that are gone
      'Spree::PromotionHandler::Page' => 'Apply the promotion with a coupon code, or make it automatic.',
      'Spree::Carts::Empty' => 'Remove items through the Store API cart items endpoints, or delete the cart with Spree.cart_destroy_service.',
      'Spree::Payments::Create' => 'Use the Store API payments endpoint, Spree::StoreCredits::Apply or Spree.gift_card_apply_workflow.',
      'Spree::Report' => 'Use reporting queries for aggregates, or a Spree::Export subclass for CSV rows.',
      'Spree::ReportLineItem' => 'Use reporting queries for aggregates, or a Spree::Export subclass for CSV rows.',
      'Spree::ImageMethods' => 'Use Active Storage variants with cdn_image_url.',
      'Spree::Frontend' => 'The Rails storefront is gone. Build the storefront on the Store API (/api/v3/store), ' \
                           'for example with the Next.js storefront and @spree/sdk.',
      'Spree::Backend' => 'The Rails admin is gone. The back office is the React Admin Dashboard on the Admin API (/api/v3/admin); ' \
                          'extend it with dashboard plugins.',
      'Spree::Api::V2' => 'API v2 is gone. Use the Store API (/api/v3/store) or the Admin API (/api/v3/admin).'
    }.freeze

    module_function

    # @param error [NameError]
    # @return [String, nil] the hint for a removed Spree API, or nil
    def hint_for(error)
      key, replacement = lookup(error)
      return unless key

      "Spree 6.0 removed #{key}. #{replacement}\nUpgrade guide: #{UPGRADE_GUIDE_URL}"
    rescue StandardError
      nil
    end

    def lookup(error)
      name = error.name.to_s
      receiver = error.receiver

      if error.is_a?(NoMethodError)
        method_lookup(receiver, name)
      elsif receiver.is_a?(Module)
        constant_lookup(receiver, name)
      end
    end

    def method_lookup(receiver, name)
      if receiver.is_a?(Module)
        ancestor_lookup(receiver, ".#{name}")
      elsif defined?(ActiveRecord::Relation) && receiver.is_a?(ActiveRecord::Relation)
        ancestor_lookup(receiver.klass, ".#{name}")
      else
        ancestor_lookup(receiver.class, "##{name}")
      end
    end

    def ancestor_lookup(klass, suffix)
      klass.ancestors.each do |ancestor|
        key = "#{ancestor.name}#{suffix}"
        return [key, REPLACEMENTS[key]] if REPLACEMENTS.key?(key)
      end
      nil
    end

    # A lexical lookup inside Spree code reports its own namespace as the
    # receiver, so 'Spree::Order::ReturnAuthorization' also tries 'Spree::ReturnAuthorization'.
    def constant_lookup(receiver, name)
      candidates = receiver == Object ? [name] : ["#{receiver.name}::#{name}"]
      candidates << "Spree::#{name}" if receiver.name.to_s.start_with?('Spree::')
      key = candidates.find { |candidate| REPLACEMENTS.key?(candidate) }
      [key, REPLACEMENTS[key]] if key
    end

    # Prepended to NameError (and so NoMethodError).
    module ErrorHint
      def detailed_message(**)
        message = super
        hint = Spree::RemovedApis.hint_for(self)
        hint ? "#{message}\n\n#{hint}" : message
      end
    end
  end
end

NameError.prepend(Spree::RemovedApis::ErrorHint)
