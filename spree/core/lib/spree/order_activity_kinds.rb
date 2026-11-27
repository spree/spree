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
    Kind = Struct.new(:category, :builder, keyword_init: true)

    POST_SALE_EVENTS = {
      'return' => %w[return.requested return.received return.refunded return.canceled],
      'exchange' => %w[exchange.requested exchange.received exchange.fulfilled exchange.canceled],
      'claim' => %w[claim.opened claim.resolved claim.denied claim.canceled]
    }.freeze

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

      @kinds[event_name.to_s] = Kind.new(category: category.to_s, builder: builder)
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

        { order: order, details: { total: money(order.total, order.currency) } }
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

      # A refund is recorded once the gateway answers: payment.refunded when
      # the money went back (it names the refund in its metadata),
      # refund.requested while the gateway confirms later, refund.failed when
      # it was declined. refund.created fires before the gateway is asked.
      register('payment.refunded', category: 'payments') do |event|
        refund_entry(Spree::Refund.find_by_prefix_id(event.metadata['refund_id']))
      end
      %w[refund.requested refund.failed].each do |name|
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
          # A set discarded before it was submitted was never a request.
          next if name == 'order_change.canceled' && change.requested_at.nil?

          { order: change.order, order_change: change }
        end
      end
    end

    def register_post_sale_kinds
      POST_SALE_EVENTS.each do |prefix, names|
        names.each do |name|
          register(name, category: 'returns') do |event|
            record = "Spree::#{prefix.camelize}".constantize.find_by_prefix_id(event.payload['id'])
            next unless record&.order

            # The restock or replacements the step made, which its event names.
            change = record.order_changes.find_by_prefix_id(event.metadata['order_change_id']) if event.metadata['order_change_id']
            { order: record.order, order_change: change, details: { "#{prefix}_id": record.prefixed_id, number: record.number } }
          end
        end
      end
    end

    def refund_entry(refund)
      order = refund&.order || refund&.payment&.order
      return unless order

      # The refund's own reference, never the charge it returns money from.
      details = payment_details(refund.payment).merge(refund_id: refund.prefixed_id, amount: money(refund.amount, order.currency),
                                                      reason: refund.reason&.name, transaction_id: refund.transaction_id.presence)
      { order: order, details: details.compact }
    end

    def payment_details(payment)
      {
        payment_id: payment.prefixed_id,
        payment_method: payment.payment_method&.name,
        amount: money(payment.amount, payment.currency),
        brand: payment.source.try(:brand).presence,
        last4: payment.source.try(:last4).presence,
        transaction_id: payment.response_code.presence
      }.compact
    end

    def money(amount, currency)
      Spree::Money::Rounding.format(amount, currency) unless amount.nil?
    end
  end
end
