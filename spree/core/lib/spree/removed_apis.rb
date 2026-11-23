module Spree
  # Names the replacement when code calls a Ruby API that Spree removed.
  #
  # Spree is old enough that coding agents, older tutorials and extensions
  # still reach for 4.x and 5.x APIs: the checkout state machine,
  # adjustments, single-currency prices, return authorizations. Without help,
  # those calls fail with a bare NoMethodError or NameError, and the reader
  # has to work out what replaced them. This module adds one paragraph to
  # those errors naming what to use instead.
  #
  # The hint is added to Exception#detailed_message, the text Ruby, IRB and
  # RSpec print for an error. The Rails log prints #message instead, so
  # ErrorSubscriber logs the hint for errors Rails reports (unhandled request
  # and job errors). The error keeps its class, its #message and its
  # #respond_to? answers, so rescues and duck typing behave exactly as they
  # did. Removed names are never defined, so nothing that still exists can be
  # shadowed.
  #
  # docs/developer/upgrades/removed-apis.mdx lists every entry; regenerate it
  # with UPDATE_DOCS=1 pnpm test:rspec core spec/lib/spree/removed_apis_spec.rb.
  #
  # Keys: 'Spree::Order#next' is an instance method, 'Spree::Order.checkout_flow'
  # a class method (also matched when called on a relation), 'Spree::Adjustment'
  # a constant. A key matches subclasses too.
  #
  # When you remove a public Ruby API, add it under the release that removed
  # it (see spree/AGENTS.md).
  module RemovedApis
    UPGRADE_GUIDES = {
      '6.0' => 'https://spreecommerce.org/docs/developer/upgrades/5.6-to-6.0'
    }.freeze

    # @return [Hash{String => String}] each name in +entries+, prefixed with each owner
    def self.expand(owners, separator, entries)
      owners.product(entries.to_a).to_h { |owner, (name, hint)| ["#{owner}#{separator}#{name}", hint] }
    end

    CHECKOUT = 'Checkout has no state machine. Write cart fields in any order (Spree::Carts::Update, ' \
               'or the Store API cart endpoints), read cart.current_checkout_step and the cart ' \
               'requirements to see what is missing, and place the order with ' \
               'Spree::Dependencies.carts_complete_workflow.constantize.call(cart: cart).'.freeze
    CHECKOUT_CUSTOMIZATION = 'Checkout has no state machine. Add a checkout requirement with ' \
                             'Spree::Checkout::Registry.add_requirement, or a step with Spree::Checkout::Registry.register_step, ' \
                             'and run side effects of placing an order in an order.placed subscriber (Spree::Subscriber).'.freeze
    ADJUSTMENTS = 'Adjustments are typed rows: tax_lines, discounts and fees.'.freeze
    RETURNS = 'Returns, exchanges and claims are their own records on the order: returns, exchanges, claims.'.freeze
    STATE_CHANGES = 'Status history is no longer stored. Subscribe to events instead (Spree::Subscriber).'.freeze
    PRIMARY_MEDIA = 'Use primary_media.'.freeze
    CUSTOMER_PRICE = 'Use price_in(currency).display_amount for the base price, or, on a variant (product.default_variant), ' \
                     'price_for(context).display_amount for the price a customer pays including price lists.'.freeze
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
      'price' => 'Prices are per currency: price_in(currency).amount or amount_in(currency).',
      'default_price' => 'Use price_in(currency).',
      'currency' => 'Pass the currency you mean to price_in(currency).',
      'display_price' => CUSTOMER_PRICE,
      'display_amount' => CUSTOMER_PRICE,
      'display_compare_at_price' => 'Use price_in(currency).display_compare_at_amount.',
      'price_including_vat_for' => 'Use price_in(currency).amount: prices are charged as entered.',
      'has_default_price?' => 'Use prices.base_prices.exists?(currency: currency).',
      'default_image' => PRIMARY_MEDIA,
      'primary_image' => PRIMARY_MEDIA
    }.freeze

    REPORTS = 'Use reporting queries for aggregates, or a Spree::Export subclass for CSV rows.'.freeze

    # Removed APIs by the release that removed them.
    REMOVED = {
      '6.0' => {
        # Checkout, orders and carts
        **expand(%w[Spree::Order Spree::Cart], '#', ORDER_AND_CART),
        **expand(%w[Spree::Order Spree::Cart], '.', ORDER_AND_CART_CLASS),
        'Spree::Order#line_item_adjustments' => 'Use line_item_tax_lines and line_item_discounts.',
        'Spree::Order#shipment_adjustments' => 'Use fulfillment_tax_lines and fulfillment_discounts.',
        **expand(%w[Spree::Order], '#', %w[return_authorizations customer_returns reimbursements].index_with(RETURNS)),
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
        **expand(%w[Spree::Variant Spree::Product], '#', VARIANT_AND_PRODUCT),
        'Spree::Variant#price=' => 'Use set_price(currency, amount).',
        'Spree::Variant#compare_at_price=' => 'Use set_price(currency, amount, compare_at_amount).',
        'Spree::Product#price=' => 'Set prices on a variant: default_variant.set_price(currency, amount).',
        'Spree::Product#compare_at_price=' => 'Set prices on a variant: default_variant.set_price(currency, amount, compare_at_amount).',
        'Spree::Product#featured_image' => PRIMARY_MEDIA,
        'Spree::DefaultPrice' => 'Use variant.price_in(currency) and variant.set_price(currency, amount).',
        'Spree::VatPriceCalculation' => 'Use price_in(currency).amount: prices include tax per market.',
        'Spree::Product.with_option' => 'Use with_option_value(option, value).',
        **expand(%w[Spree::Product], '.', %w[in_name in_name_or_keywords in_name_or_description].index_with(SEARCH)),
        'Spree::Product.with_ids' => 'Use where(id: ids).',
        'Spree::Product.add_search_scope' => 'Declare a plain Active Record scope. To filter by it through the Admin API (q[...]), ' \
                                             'also register it with Spree.ransack.add_scope(Spree::Product, :scope_name).',
        **expand(%w[Spree::Product Spree::Variant], '.', { 'multi_search' => SEARCH }),
        'Spree::OptionType#color?' => 'Use color_swatch?.',
        'Spree::Category#set_store' => 'Nothing to call: a new category gets its store from its parent or the current store when it is saved.',
        'Spree::Category.for_taxonomy' => 'Use for_store(taxonomy.store). It returns every category in that store, not one taxonomy.',

        # Stores, addresses, users and permissions
        'Spree::Store#admin_users' => 'Use users.',
        'Spree::Store#supported_shipping_zones' => 'Use countries_with_shipping_coverage.',
        'Spree::Address#user_default_billing?' => 'Use is_default_billing?.',
        'Spree::Address#user_default_shipping?' => 'Use is_default_shipping?.',
        'Spree.searcher_class' => 'Use Spree.search_provider.',
        'Spree::PermittedAttributes' => 'Add writable API attributes with Spree::Product.additional_permitted_attributes += [...] ' \
                                        'inside Rails.application.config.to_prepare (any model; always +=).',
        'Spree::Preference' => 'Preferences live on each model in a JSON preferences column.',
        'Spree::User' => 'Use Spree.customer_class for customers and Spree.admin_user_class for staff.',

        # Services and screens that are gone
        'Spree::PromotionHandler::Page' => 'Apply the promotion with a coupon code, or make it automatic.',
        'Spree::Carts::Empty' => 'Remove items through the Store API cart items endpoints, or delete the cart with Spree.cart_destroy_service.',
        'Spree::Payments::Create' => 'Use the Store API payments endpoint, Spree::StoreCredits::Apply or Spree.gift_card_apply_workflow.',
        'Spree::Report' => REPORTS,
        'Spree::ReportLineItem' => REPORTS,
        'Spree::ImageMethods' => 'Use Active Storage variants with cdn_image_url.',
        'Spree::Frontend' => 'The Rails storefront is gone. Build the storefront on the Store API (/api/v3/store), ' \
                             'for example with the Next.js storefront and @spree/sdk.',
        'Spree::Backend' => 'The Rails admin is gone. The back office is the React Admin Dashboard on the Admin API (/api/v3/admin); ' \
                            'extend it with dashboard plugins.',
        'Spree::Api::V2' => 'API v2 is gone. Use the Store API (/api/v3/store) or the Admin API (/api/v3/admin).'
      }.freeze
    }.freeze

    module_function

    # @param error [NameError]
    # @return [String, nil] the hint for a removed Spree API, or nil
    def hint_for(error)
      key = lookup(error)
      return unless key

      version, entries = REMOVED.find { |_release, removed| removed.key?(key) }
      "Spree #{version} removed #{key}. #{entries[key]}\nUpgrade guide: #{UPGRADE_GUIDES.fetch(version)}"
    rescue StandardError
      nil
    end

    def known?(key)
      REMOVED.each_value.any? { |entries| entries.key?(key) }
    end

    # A receiverless call (`state` inside an Order decorator) raises a plain
    # NameError, so only a capitalized name is treated as a constant.
    def lookup(error)
      name = error.name.to_s
      receiver = error.receiver

      if error.is_a?(NoMethodError) || !name.match?(/\A[A-Z]/)
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
        return key if known?(key)
      end
      nil
    end

    # Code written directly inside the Spree namespace (`module Spree; module
    # OrderDecorator`) reports its own module as the receiver of a missing
    # constant, so 'Spree::OrderDecorator::Adjustment' also tries 'Spree::Adjustment'.
    # Deeper namespaces don't, so a missing Spree::Reporting::Report is not
    # mistaken for the removed Spree::Report.
    def constant_lookup(receiver, name)
      candidates = receiver == Object ? [name] : ["#{receiver.name}::#{name}"]
      candidates << "Spree::#{name}" if receiver.name.to_s.match?(/\ASpree::\w+\z/)
      candidates.find { |candidate| known?(candidate) }
    end

    # @return [String] the documentation page listing every removed API
    def to_mdx
      sections = REMOVED.map do |version, entries|
        rows = entries.map { |key, replacement| "| `#{key}` | #{replacement} |" }
        <<~MARKDOWN
          ## Removed in Spree #{version}

          See the [upgrade guide](#{UPGRADE_GUIDES.fetch(version)}) for the reasons behind each change.

          | Removed | Use instead |
          | --- | --- |
          #{rows.join("\n")}
        MARKDOWN
      end

      <<~MARKDOWN
        ---
        title: Removed Ruby APIs
        description: Ruby classes and methods removed from Spree, and what replaced each one.
        ---

        Code written for an older Spree release, or by a coding agent working from old examples, may call one of these APIs. It fails with a `NoMethodError` or `NameError`, and Ruby, the Rails console, RSpec and the Rails log add the replacement below to that error.

        APIs that still work but print a deprecation warning are not listed here. They are in the upgrade guide for the release that deprecated them.

        #{sections.join("\n")}
      MARKDOWN
    end

    # Logs the hint for an error Rails reports, such as an unhandled error in
    # a request or a job, so it appears in the Rails log next to the error.
    class ErrorSubscriber
      def report(error, **)
        hint = Spree::RemovedApis.hint_for(error) if error.is_a?(NameError)
        Rails.logger&.warn(hint) if hint
      end
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
