module Spree
  # Which events reach an order's timeline, and what each one records
  # (docs/plans/6.1-order-timeline.md).
  #
  # A builder turns an event into the attributes of a {Spree::OrderActivity},
  # or into nil when the event says nothing worth showing on that order. It
  # names the order and may add `order_change` and a small `details` hash;
  # the kind, category and actor are filled in by the subscriber.
  #
  #   Spree.order_activity_kinds.register('loyalty.points_awarded', category: 'loyalty') do |event|
  #     order = Spree::Order.find_by_prefix_id(event.payload['order_id'])
  #     next unless order
  #
  #     { order: order, details: { points: event.payload['points'] } }
  #   end
  class OrderActivityKinds
    Kind = Struct.new(:event_name, :category, :builder, keyword_init: true)

    def initialize
      @kinds = {}
      register_defaults
    end

    # @param event_name [String] the event that records the entry
    # @param category [String] what the timeline groups and filters it under
    # @yieldparam event [Spree::Event]
    # @yieldreturn [Hash, nil] `order:`, and optionally `order_change:` and `details:`
    def register(event_name, category:, &builder)
      raise ArgumentError, 'A builder block is required' unless builder

      @kinds[event_name.to_s] = Kind.new(event_name: event_name.to_s, category: category.to_s, builder: builder)
    end

    # @param event_name [String]
    def unregister(event_name)
      @kinds.delete(event_name.to_s)
    end

    # @param event_name [String]
    # @return [Kind, nil]
    def [](event_name)
      @kinds[event_name.to_s]
    end

    # @return [Array<String>]
    def event_names
      @kinds.keys
    end

    # @return [Array<String>] every category, comments included
    def categories
      (@kinds.values.map(&:category) + ['comments']).uniq
    end

    private

    def register_defaults
      register_order_kinds
      register_payment_kinds
      register_fulfillment_kinds
      register_order_change_kinds
      register_post_sale_kinds
    end

    def register_order_kinds
      register('order.placed', category: 'order') do |event|
        order = Spree::Order.find_by_prefix_id(event.payload['id'])
        next unless order

        payments = order.payments.includes(:payment_method, :source).map { |payment| payment_details(payment) }
        { order: order, details: { total: money(order.total, order.currency), currency: order.currency, payments: payments } }
      end

      %w[order.approved order.canceled].each do |name|
        register(name, category: 'order') { |event| { order: Spree::Order.find_by_prefix_id(event.payload['id']) } }
      end
    end

    def register_payment_kinds
      # payment.captured accompanies payment.completed for the same
      # settlement, so only the completion is recorded.
      %w[payment.completed payment.capture_failed payment.voided payment.void_failed].each do |name|
        register(name, category: 'payments') do |event|
          payment = Spree::Payment.find_by_prefix_id(event.payload['id'])
          { order: payment.order, details: payment_details(payment) } if payment&.order
        end
      end

      # payment.refunded describes the same refund, so only the refund's own
      # events are recorded.
      %w[refund.created refund.failed].each do |name|
        register(name, category: 'payments') { |event| refund_entry(Spree::Refund.find_by_prefix_id(event.payload['id'])) }
      end
    end

    def register_fulfillment_kinds
      %w[fulfillment.fulfilled fulfillment.delivered fulfillment.canceled].each do |name|
        register(name, category: 'fulfillment') do |event|
          fulfillment = Spree::Fulfillment.find_by_prefix_id(event.payload['id'])
          next unless fulfillment&.order

          { order: fulfillment.order,
            details: { fulfillment_id: fulfillment.prefixed_id, number: fulfillment.number, tracking: fulfillment.tracking }.compact }
        end
      end
    end

    # A change made by a return, exchange or claim is shown under that
    # record's entry. A change requested and confirmed in one call has been
    # confirmed by the time its requested event arrives, so it is recorded
    # once, as confirmed.
    def register_order_change_kinds
      %w[order_change.requested order_change.confirmed order_change.canceled].each do |name|
        register(name, category: 'changes') do |event|
          change = Spree::OrderChange.find_by_prefix_id(event.payload['id'])
          next if change.nil? || change.post_sale_record
          next if name == 'order_change.requested' && !change.requested?

          { order: change.order, order_change: change }
        end
      end
    end

    def register_post_sale_kinds
      %w[return exchange claim].each do |prefix|
        post_sale_events(prefix).each do |name|
          register(name, category: 'returns') do |event|
            record = "Spree::#{prefix.camelize}".constantize.find_by_prefix_id(event.payload['id'])
            next unless record&.order

            { order: record.order, order_change: post_sale_change(name, record),
              details: { "#{prefix}_id": record.prefixed_id, number: record.number } }
          end
        end
      end
    end

    def refund_entry(refund)
      order = refund&.order || refund&.payment&.order
      return unless order

      details = payment_details(refund.payment).merge(refund_id: refund.prefixed_id, amount: money(refund.amount, order.currency),
                                                      reason: refund.reason&.name)
      { order: order, details: details.compact }
    end

    def post_sale_events(prefix)
      {
        'return' => %w[return.requested return.received return.refunded return.canceled],
        'exchange' => %w[exchange.requested exchange.received exchange.fulfilled exchange.canceled],
        'claim' => %w[claim.opened claim.resolved claim.denied claim.canceled]
      }.fetch(prefix)
    end

    # The change set the step just confirmed: the restock on receipt, the
    # replacements on fulfillment or resolution.
    def post_sale_change(event_name, record)
      return unless event_name.end_with?('.received', '.fulfilled', '.resolved')

      record.order_changes.where(status: 'confirmed').order(:confirmed_at, :id).last
    end

    def payment_details(payment)
      {
        payment_id: payment.prefixed_id,
        payment_method: payment.payment_method&.name,
        amount: money(payment.amount, payment.currency),
        brand: payment.source.try(:cc_type).presence,
        last_digits: payment.source.try(:last_digits).presence,
        transaction_id: payment.response_code.presence
      }.compact
    end

    def money(amount, currency)
      Spree::Money::Rounding.format(amount, currency) unless amount.nil?
    end
  end
end
