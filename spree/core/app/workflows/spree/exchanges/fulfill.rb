module Spree
  module Exchanges
    # Ships the replacements and settles the difference in price.
    #
    # The money branch mirrors Returns::Refund: a credit the customer is owed
    # can be store credit (an internal ledger write, inside the transaction)
    # or a gateway refund (outside it). A balance the customer owes is left
    # for the merchant to collect — charging a stored card without a fresh
    # authorization is not something core should do silently.
    class Fulfill < Spree::Workflow
      hooks :validate, :before_settle, :after_fulfill

      # Fulfillments created for the replacement items.
      attr_reader :fulfillments, :refunds

      # @param exchange [Spree::Exchange] must be received
      # @param refund_method [String] how a credit is returned when the
      #   replacements are cheaper: 'store_credit' or 'original_payment'
      # @param refunder [Object, nil]
      def perform(exchange:, refund_method: 'store_credit', refunder: nil)
        super

        @fulfillments = []
        @refunds = []
        step :ensure_fulfillable
        run_hooks :validate

        ApplicationRecord.transaction do
          step :build_replacement_fulfillments
          run_hooks :before_settle
          step :issue_store_credit if credit_due? && internal_refund?
          step :mark_fulfilled
        end

        external_step :refund_at_gateway if credit_due? && !internal_refund?

        step :recalculate_order
        run_hooks :after_fulfill
        exchange.publish_event('exchange.fulfilled')
        success(exchange.reload)
      end

      private

      def internal_refund?
        refund_method.to_s == 'store_credit'
      end

      # Negative price difference means the replacements cost less than what
      # came back, so the customer is owed the difference.
      def credit_due?
        exchange.price_difference.to_d.negative?
      end

      def credit_amount
        exchange.price_difference.to_d.abs
      end

      def ensure_fulfillable
        if credit_due? && !Spree::RefundMethods.valid?(refund_method)
          # :base, not :refund_method — it is a workflow argument, not an
          # attribute, and ActiveModel raises when an error names one that
          # does not exist on the record.
          exchange.errors.add(:base, :invalid_refund_method,
                           message: Spree.t('errors.messages.invalid_refund_method'))
          failure(exchange)
        end
        failure(exchange, :not_received) unless exchange.received?
      end

      # Only lines that actually came back are replaced — a customer who
      # returned two of three items gets two replacements.
      def build_replacement_fulfillments
        units = exchange.exchange_line_items.filter_map do |line|
          next if line.received_quantity.to_i.zero?

          exchange.order.fulfillment_items.new(
            variant: line.new_variant,
            quantity: line.received_quantity,
            line_item: line.line_item,
            order: exchange.order,
            status: 'on_hand'
          )
        end

        failure(exchange, :nothing_to_fulfill) if units.empty?

        @fulfillments = Spree::Stock::Coordinator.new(exchange.order, units).fulfillments
        if @fulfillments.flat_map(&:fulfillment_items).sum(&:quantity) != units.sum(&:quantity)
          failure(exchange, :replacement_out_of_stock)
        end

        exchange.order.fulfillments += @fulfillments
        exchange.order.save!
        @fulfillments.each { |fulfillment| fulfillment.update!(exchange.order) }
      end

      def issue_store_credit
        @refunds = [
          Spree::StoreCredit.create!(
            store: exchange.store,
            customer: exchange.order.customer,
            amount: credit_amount,
            currency: exchange.currency,
            category: Spree::StoreCreditCategory.default_refund_category,
            created_by: refunder,
            originator: exchange,
            memo: "Exchange #{exchange.number}"
          )
        ]
      end

      def refund_at_gateway
        remaining = credit_amount
        exchange.order.payments.completed.each do |payment|
          break unless remaining.positive?

          creditable = [payment.credit_allowed.to_d, remaining].min
          next unless creditable.positive?

          # One refund path for the whole system: Refunds::Create owns the
          # row-lock balance check, the gateway credit, the declined-row
          # compensation, the refund hooks and the payment.refunded event.
          result = Spree.refund_create_workflow.call(
            payment: payment,
            amount: creditable,
            reason: Spree::RefundReason.return_processing_reason(exchange.store),
            refunder: refunder,
            originator: exchange
          )
          failure(exchange, result.error.value) if result.failure?

          @refunds << result.value
          remaining -= creditable
        end
      end

      def mark_fulfilled
        exchange.update!(status: 'fulfilled', fulfilled_at: Time.current)
      end

      def recalculate_order
        exchange.order.recalculate_totals!
      end
    end
  end
end
