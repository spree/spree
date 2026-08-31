module Spree
  module Checkout
    # Built-in checkout requirements that map to the standard Spree checkout flow.
    #
    # Checks line items, email, shipping address, shipping method, and payment
    # against the cart — checkout is a cart-phase concern. The heavier
    # completion-only checks (per-item stock, discontinued products, guest
    # policy) run only when +completion: true+ is passed, so the advisory
    # requirements feed on cart reads stays cheap.
    #
    # @see Requirements
    class DefaultRequirements
      # @param cart [Spree::Cart]
      def initialize(cart)
        @cart = cart
      end

      # @param completion [Boolean] include the completion-only checks
      # @return [Array<Hash{Symbol => String}>] unmet requirements as
      #   +{ step:, field:, code:, message: }+ hashes
      def call(completion: false)
        requirements = advisory_requirements
        return requirements unless completion

        requirements + completion_requirements
      end

      private

      def advisory_requirements
        [].tap do |r|
          r << req('cart', 'line_items', Spree.t('checkout_requirements.line_items_required')) unless @cart.line_items.any?
          r << req('address', 'email', Spree.t('checkout_requirements.email_required')) unless @cart.email.present?
          r << req('address', 'ship_address', Spree.t('checkout_requirements.ship_address_required')) if @cart.shipping_address_required? && @cart.ship_address.blank?
          r << req('delivery', 'delivery_method', Spree.t('checkout_requirements.delivery_method_required')) if delivery_step_required? && !delivery_method_selected?
          r << req('payment', 'payment', Spree.t('checkout_requirements.payment_required')) if payment_required? && !payment_satisfied?
          r << req('address', 'po_number', Spree.t('checkout_requirements.po_number_required')) if po_number_missing?
          r << order_minimum_requirement if below_order_minimum?
        end
      end

      def completion_requirements
        errors = stock_errors + quantity_rule_errors
        errors << req('address', 'email', Spree.t(:guest_checkout_not_allowed), code: 'guest_checkout_not_allowed') if @cart.guest_checkout_disallowed?
        errors << company_requirement if @cart.company_activation_missing?
        errors.compact
      end

      # Two distinct remediations behind one gate: a buyer whose standing
      # covers an active company merely has to say which node the order is
      # for (the same test that shows them prices), while everyone else has
      # to register or await activation. One code for both would send the
      # multi-company buyer to a "register your business" page.
      def company_requirement
        code = Spree.company_activation_policy_class.new.
               pricing_access_code(user: @cart.customer, store: @cart.store)

        if code.nil?
          req('address', 'company', Spree.t('checkout_requirements.company_selection_required'), code: 'company_selection_required')
        else
          req('address', 'company', Spree.t('checkout_requirements.company_activation_required'), code: 'company_activation_required')
        end
      end

      # Re-checked at completion because an agreement can change between the
      # add and the checkout — a company moved to a different tier, a term
      # edited. Naming the nearest valid quantities rather than rounding: a
      # silent adjustment on a wholesale order is a five-figure surprise.
      def quantity_rule_errors
        @cart.quantity_rule_violations.map do |_line_item, message|
          req('cart', 'line_items', message, code: 'quantity_rule_violated')
        end
      end

      # Advisory rather than completion-only: a buyer has to be able to build
      # the order below the threshold and read how far off they are while
      # they can still add to it. Completion refuses it because the advisory
      # feed is included there too.
      def below_order_minimum?
        !@cart.staff_initiated? && @cart.below_order_minimum?
      end

      def order_minimum_requirement
        minimum = @cart.order_minimum
        shortfall = Spree::Money.new(@cart.order_minimum_shortfall, currency: minimum.currency)

        req('cart', 'order_minimum',
            Spree.t('checkout_requirements.order_minimum_not_met',
                    minimum: minimum.display_amount.to_s, shortfall: shortfall.to_s),
            code: 'order_minimum_not_met')
      end

      # Discontinuation is checked at both levels: a product can stay active
      # while an individual variant hit its discontinue_on date after it
      # entered the cart.
      def stock_errors
        @cart.line_items.includes(variant: :product).filter_map do |line_item|
          if line_item.variant.nil? || line_item.variant.discontinued? || line_item.variant.product.discontinued?
            req('cart', 'line_items', Spree.t('cart_line_item.discontinued', li_name: line_item.name), code: 'discontinued')
          elsif !line_item.sufficient_stock?
            req('cart', 'line_items', Spree.t('cart_line_item.out_of_stock', li_name: line_item.name), code: 'out_of_stock')
          end
        end
      end

      def delivery_step_required?
        @cart.delivery_step_required?
      end

      def delivery_method_selected?
        @cart.fulfillments.any? && @cart.fulfillments.all? { |fulfillment| fulfillment.delivery_method.present? }
      end

      def payment_required?
        @cart.payment_required?
      end

      def payment_satisfied?
        @cart.payments.valid.any?
      end

      # Advisory rather than completion-only: the buyer has to be told the
      # reference is needed while they can still type it, not refused at the
      # end of checkout. Staff keying an order in are exempt — the buyer's PO
      # commonly arrives with the paperwork rather than at the till.
      #
      # Reported against `address` rather than `payment`: payment is dropped
      # from the steps of a cart that owes nothing, and a requirement naming a
      # step the buyer never visits is one they cannot clear.
      def po_number_missing?
        @cart.po_number.blank? && @cart.po_number_required? && !keyed_in_by_staff?
      end

      # Narrower than {Spree::Purchase::QuantityRules#staff_initiated?} on
      # purpose. A buyer's PO reference commonly arrives with the paperwork,
      # so only an order someone actually keyed in is excused — a draft with
      # no recorded creator still has to ask for it. Quantity terms take the
      # wider exemption: any draft order is the admin surface, and refusing
      # staff there would make an agreed exception impossible to record.
      def keyed_in_by_staff?
        @cart.respond_to?(:created_by_id) && @cart.created_by_id.present?
      end

      def req(step, field, message, code: nil)
        { step: step, field: field, code: code || "#{field}_required", message: message }
      end
    end
  end
end
