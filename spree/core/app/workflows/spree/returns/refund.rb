module Spree
  module Returns
    # Gives the customer their money back.
    #
    # Not every refund is a network call. Store credit is an internal ledger
    # write, so it stays inside the transaction that marks the return
    # refunded; a gateway refund runs as an `external_step` after it. Sending
    # a pure database write outside the transaction would open a window where
    # a crash leaves a refunded return with no credit issued.
    class Refund < Spree::Workflow
      hooks :validate, :before_refund, :after_refund

      # Refunds created by this run — hook handlers read them.
      attr_reader :refunds

      # @param return_record [Spree::Return] must be received
      # @param amount [BigDecimal, Numeric, nil] defaults to what the return
      #   is still owed
      # @param refund_method [String] 'original_payment' or 'store_credit'
      # @param refunder [Object, nil] the admin issuing it
      def perform(return_record:, amount: nil, refund_method: 'original_payment', refunder: nil)
        super

        @refunds = []
        step :ensure_refundable
        step :resolve_amount

        run_hooks :validate
        run_hooks :before_refund

        if internal_refund?
          ApplicationRecord.transaction do
            step :issue_store_credit
            step :mark_refunded
          end
        else
          external_step :refund_at_gateway
          step :mark_refunded
        end

        external_step :refund_tax
        run_hooks :after_refund
        return_record.publish_event('return.refunded')
        success(return_record.reload)
      end

      private

      # Credits the returned items against the filed tax document, keyed to the
      # original supply date rather than today's — the rate that applied then is
      # the rate to credit back.
      def refund_tax
        order = return_record.order
        order.tax_provider.refund(order, return_record.return_line_items.to_a, tax_date: order.completed_at)
      end

      def internal_refund?
        refund_method.to_s == 'store_credit'
      end

      def ensure_refundable
        unless Spree::RefundMethods.valid?(refund_method)
          # :base, not :refund_method — it is a workflow argument, not an
          # attribute, and ActiveModel raises when an error names one that
          # does not exist on the record.
          return_record.errors.add(:base, :invalid_refund_method,
                           message: Spree.t('errors.messages.invalid_refund_method'))
          failure(return_record)
        end
        failure(return_record, :not_received) unless return_record.received?
      end

      # Only what actually came back is refundable — a customer who sent two
      # of three items gets two items' worth.
      def resolve_amount
        @amount_to_refund = (amount || received_total).to_d

        failure(return_record, :nothing_to_refund) unless @amount_to_refund.positive?
        failure(return_record, :refund_exceeds_balance) if @amount_to_refund > return_record.refundable_total.to_d
      end

      def received_total
        return_record.return_line_items.sum do |line|
          next 0 if line.quantity.to_i.zero?

          (line.pre_tax_amount / line.quantity) * line.received_quantity.to_i
        end
      end

      def issue_store_credit
        credit = Spree::StoreCredit.create!(
          store: return_record.store,
          customer: return_record.order.customer,
          amount: @amount_to_refund,
          currency: return_record.currency,
          category: Spree::StoreCreditCategory.default_refund_category,
          created_by: refunder,
          originator: return_record,
          memo: "Return #{return_record.number}"
        )
        @refunds = [credit]
      end

      # Spree::Refund performs the gateway credit in an after_create callback,
      # so creating it here keeps that call out of any transaction this
      # workflow opened. Payments are drained newest-first until the amount
      # is covered — a split-tender order needs more than one refund.
      def refund_at_gateway
        remaining = @amount_to_refund

        return_record.order.payments.completed.each do |payment|
          break unless remaining.positive?

          creditable = [payment.credit_allowed.to_d, remaining].min
          next unless creditable.positive?

          @refunds << payment.refunds.create!(
            amount: creditable,
            reason: Spree::RefundReason.return_processing_reason(return_record.store),
            refunder: refunder,
            originator: return_record
          )
          remaining -= creditable
        end

        failure(return_record, :no_refundable_payments) if @refunds.empty?
      rescue Spree::Core::GatewayError => error
        failure(return_record, error.message)
      end

      def mark_refunded
        return_record.update!(status: 'refunded', refunded_at: Time.current)
      end
    end
  end
end
