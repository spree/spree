class Spree::ReimbursementType::OriginalPayment < Spree::ReimbursementType
  class << self
    def reimburse(reimbursement, return_items, simulate)
      refund_list = []
      unpaid_amount = return_items.sum(&:total).round(2)
      payments = reimbursement.order.payments.completed

      payments.map do |payment|
        break if unpaid_amount <= 0
        next if payment.credit_allowed.zero?

        amount = [unpaid_amount, payment.credit_allowed].min
        refund_list << create_refund(reimbursement, payment, amount, simulate)
        unpaid_amount -= amount
      end

      refund_list
    end

    private

    def create_refund(reimbursement, payment, amount, simulate)
      refund = reimbursement.refunds.build({
        payment: payment,
        amount: amount,
        reason: Spree::RefundReason.return_processing_reason,
      })

      simulate ? refund.readonly! : refund.save!
      refund
    end
  end
end
