module Spree
  module Returns
    # What a customer would be told if they asked to send something back from
    # this order now, before they have picked anything.
    #
    # The verdict comes from the `returns.create.validate` handlers
    # themselves, run with nothing written (Spree::Workflow.check_hook), so a
    # storefront shows exactly what the create call would answer — including
    # the rules a store registered on its own. Nothing here restates a rule.
    #
    # Read through Spree::Order#returns_eligibility, which memoizes it per
    # order instance so one serialization pays for it once.
    class Eligibility
      attr_reader :order

      # @param order [Spree::Order]
      def initialize(order)
        @order = order
      end

      # @return [Boolean] whether the order is open to customer returns at all
      def eligible?
        errors.empty?
      end

      # Why the order is closed to customer returns, as code and message pairs
      # a storefront can show or translate.
      #
      # @return [Array<Hash{Symbol => String}>]
      def errors
        @errors ||= order_errors.presence || hook_errors(items: [])
      end

      # How much of one shipped unit the customer may still send back, and
      # why not when the answer is nothing.
      #
      # @param unit [Spree::FulfillmentItem]
      # @return [Hash] `{ returnable_quantity: Integer, non_returnable_reason: String | nil }`
      def for_unit(unit)
        return { returnable_quantity: 0, non_returnable_reason: errors.first[:code] } unless eligible?

        remaining = unit.quantity.to_i - claimed_quantities.fetch(unit.id, 0)
        reason =
          if remaining <= 0
            'already_returned'
          else
            hook_errors(items: [{ fulfillment_item: unit, quantity: remaining }]).first&.dig(:code)
          end

        { returnable_quantity: reason ? 0 : remaining, non_returnable_reason: reason }
      end

      # One line of a parcel, unit by unit, as the Store API serves it: what
      # may still come back in total, why not when nothing can, and each unit
      # with its `fulfillment_item_id`, which opening a return takes.
      #
      # @param units [Array<Spree::FulfillmentItem>]
      # @return [Hash]
      def for_units(units)
        self.class.summarize(units) { |unit| for_unit(unit) }
      end

      # The same shape for units with no order to judge them by, such as a
      # cart's.
      #
      # @param units [Array<Spree::FulfillmentItem>]
      # @return [Hash]
      def self.closed(units)
        summarize(units) { { returnable_quantity: 0, non_returnable_reason: 'order_not_completed' } }
      end

      # @return [Hash] the units with their verdicts and the line's summary
      def self.summarize(units)
        unit_rows = units.map do |unit|
          { fulfillment_item_id: unit.prefixed_id, quantity: unit.quantity }.merge(yield(unit))
        end
        returnable_quantity = unit_rows.sum { |row| row[:returnable_quantity] }

        {
          returnable_quantity: returnable_quantity,
          non_returnable_reason: returnable_quantity.zero? ? unit_rows.first&.dig(:non_returnable_reason) : nil,
          units: unit_rows
        }
      end

      # @return [Hash] the shape the Store API serves
      def to_h
        {
          eligible: eligible?,
          errors: errors,
          return_window_ends_at: order.return_window_ends_at&.iso8601,
          withdrawal_period_ends_at: order.withdrawal_period_ends_at&.iso8601
        }
      end

      private

      # The workflow's own refusals, which run before its hooks.
      def order_errors
        code = if order.canceled? then :order_canceled
               elsif !order.completed? then :order_not_completed
               end
        code ? [{ code: code.to_s, message: I18n.t("spree.return_errors.#{code}") }] : []
      end

      # A store's handler was written for the real create call, which never
      # passes it an empty list. If one raises here, the preview says nothing
      # rather than failing the order read; the create call still judges.
      def hook_errors(items:)
        errors = Spree.return_create_workflow.check_hook(
          :validate,
          order: order, items: items, stock_location: nil, reason: nil, memo: nil, created_by: nil
        )

        errors.map do |error|
          { code: error.type.is_a?(Symbol) ? error.type.to_s : 'rejected', message: error.message }
        end
      rescue StandardError => e
        Rails.error.report(e, handled: true, context: { order_id: order.id }, source: 'spree.returns.eligibility')
        # For the order as a whole the preview stays quiet; for a unit, a rule
        # that could not answer must not read as "returnable".
        items.empty? ? [] : [{ code: 'unavailable', message: I18n.t('spree.return_errors.unavailable') }]
      end

      def claimed_quantities
        @claimed_quantities ||= Spree::Returns::ReturnableQuantity.claimed_quantities(
          order.fulfillments.flat_map(&:fulfillment_items).map(&:id)
        )
      end
    end
  end
end
