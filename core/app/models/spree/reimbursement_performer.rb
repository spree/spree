module Spree

  class ReimbursementPerformer

    class << self

      # Simulate performing the reimbursement without actually saving anything or refunding money, etc.
      # This must return an array of objects that respond to the following methods:
      # - #description
      # - #display_amount
      # so they can be displayed in the Admin UI appropriately.
      def simulate(reimbursement)
        execute(reimbursement, true)
      end

      # Actually perform the reimbursement
      def perform(reimbursement)
        execute(reimbursement, false)
      end

      private

      def execute(reimbursement, simulate)
        # For now type and order of retrieved payments are not specified
        reimbursement_items = []
        unpaid_amount = reimbursement.unpaid_amount
        reimbursement.order.payments.completed.each do |payment|
          break if unpaid_amount <= 0
          next if payment.credit_allowed.zero?

          amount = [unpaid_amount, payment.credit_allowed].min

          refund = reimbursement.refunds.build({
            payment: payment,
            amount: amount,
            reason: Spree::RefundReason.return_processing_reason,
          })

          if simulate
            refund.readonly!
          else
            refund.save!
          end
          unpaid_amount -= amount
          reimbursement_items << refund
        end

        if exchange_items = reimbursement.reimbursement_items_requiring_exchange.presence
          exchange = Spree::Exchange.new(reimbursement.order, exchange_items)
          exchange.perform! unless simulate
          reimbursement_items << exchange
        end

        reimbursement_items
      end

    end

  end

end
