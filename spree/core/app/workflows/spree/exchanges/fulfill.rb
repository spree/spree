module Spree
  module Exchanges
    # Ships the replacements and settles the difference in price.
    #
    # Both halves of the swap carry tax: the units that came back are credited
    # the tax the customer paid on them, and the replacements are taxed as a
    # new sale. The difference between the two, tax included, is what settles.
    #
    # The money branch mirrors Returns::Refund: a credit the customer is owed
    # can be store credit (an internal ledger write, inside the transaction)
    # or a gateway refund (outside it). A balance the customer owes is put on
    # the order as a fee for the merchant to collect — charging a stored card
    # without a fresh authorization is not something core should do silently.
    class Fulfill < Spree::Workflow
      include Spree::Refunds::OrderPayments
      include Spree::Refunds::TaxCredit
      include Spree::Fulfillments::Replacements

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
        step :ensure_received
        step :settle_tax
        step :ensure_refund_method
        run_hooks :validate

        ApplicationRecord.transaction do
          step :build_replacement_fulfillments
          run_hooks :before_settle
          step :issue_store_credit if credit_due? && internal_refund?
          step :charge_balance if balance_owed?
          step :mark_fulfilled
        end

        external_step :refund_at_gateway if credit_due? && !internal_refund?
        external_step :refund_tax
        external_step :commit_replacement

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
        settled_difference.negative?
      end

      def balance_owed?
        settled_difference.positive?
      end

      def credit_amount
        settled_difference.abs
      end

      # The difference on the units that actually came back — the same units
      # the replacements are shipped for. Priced on the requested quantity, an
      # exchange that asked for more than arrived would pay credit for goods
      # nobody returned.
      def settled_difference
        @settled_difference ||= received_lines.sum(0.to_d) { |line| line.settled_charge - line.settled_credit }
      end

      def received_lines
        @received_lines ||= exchange.exchange_line_items.select { |line| line.received_quantity.to_i.positive? }
      end

      def ensure_received
        failure(exchange, :not_received) unless exchange.received?
      end

      # Rewrites both halves' rows for the units that arrived, before any money
      # moves, so the difference settled is the one the rows record.
      def settle_tax
        with_tax_provider(exchange) { exchange.settle_tax! }
      end

      def ensure_refund_method
        return unless credit_due? && !Spree::RefundMethods.valid?(refund_method)

        # :base, not :refund_method — it is a workflow argument, not an
        # attribute, and ActiveModel raises when an error names one that
        # does not exist on the record.
        exchange.errors.add(:base, :invalid_refund_method,
                            message: Spree.t('errors.messages.invalid_refund_method'))
        failure(exchange)
      end

      # Only lines that actually came back are replaced — a customer who
      # returned two of three items gets two replacements.
      def build_replacement_fulfillments
        items = received_lines.map do |line|
          { variant: line.new_variant, quantity: line.received_quantity, line_item: line.line_item }
        end

        failure(exchange, :nothing_to_fulfill) if items.empty?

        @fulfillments = build_replacements(exchange, items)
      end

      def issue_store_credit
        @refunds = issue_refund_store_credit(
          order: exchange.order,
          amount: credit_amount,
          record: exchange,
          memo: "Exchange #{exchange.number}",
          refunder: refunder
        )
      end

      def refund_at_gateway
        @refunds = refund_order_payments(
          order: exchange.order,
          amount: credit_amount,
          record: exchange,
          refunder: refunder,
          tax_amount: received_lines.sum(0.to_d, &:settled_tax)
        )
      end

      # Puts what the customer owes on the order, which then shows it as due
      # for the merchant to collect through the order's payments.
      def charge_balance
        result = Spree.order_fee_create_service.call(
          order: exchange.order,
          attributes: {
            kind: 'exchange',
            amount: settled_difference,
            label: Spree.t(:exchange_fee_label, number: exchange.number),
            metadata: { 'exchange_id' => exchange.prefixed_id }
          }
        )

        failure(exchange, result.error.value) if result.failure?
      end

      def refund_tax
        file_tax_credit(exchange, received_lines, received_lines.sum(0.to_d, &:settled_credit))
      end

      # Reported rather than raised, as the credit is: the goods have shipped.
      def commit_replacement
        order = exchange.order
        order.tax_provider.commit_replacement(order, received_lines)
      rescue Spree::Tax::ProviderError => error
        Rails.error.report(error, handled: true, context: tax_report_context(exchange), source: 'spree.post_sale')
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
