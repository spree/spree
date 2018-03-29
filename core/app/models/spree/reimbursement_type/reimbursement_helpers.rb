module Spree
  module ReimbursementType::ReimbursementHelpers
    def create_refunds(reimbursement, payments, unpaid_amount, simulate, reimbursement_list = [])
      payments.each do |payment|
        break if unpaid_amount <= 0
        next unless payment.can_credit?

        amount = [unpaid_amount, payment.credit_allowed].min
        reimbursement_list << create_refund(reimbursement, payment, amount, simulate)
        unpaid_amount -= amount
      end

      [reimbursement_list, unpaid_amount]
    end

    def create_credits(reimbursement, unpaid_amount, simulate, reimbursement_list = [])
      credits = [create_credit(reimbursement, unpaid_amount, simulate)]
      unpaid_amount -= credits.sum(&:amount)
      reimbursement_list += credits

      [reimbursement_list, unpaid_amount]
    end

    private

    def create_refund(reimbursement, payment, amount, simulate)
      refund = reimbursement.refunds.build(
        payment: payment,
        amount: amount,
        reason: Spree::RefundReason.return_processing_reason
      )

      simulate ? refund.readonly! : refund.save!
      refund
    end

    # If you have multiple methods of crediting a customer, overwrite this method
    # Must return an array of objects the respond to #description, #display_amount
    def create_credit(reimbursement, unpaid_amount, simulate)
      category = Spree::StoreCreditCategory.default_reimbursement_category(category_options(reimbursement))
      creditable = Spree::StoreCredit.new(store_credit_params(category, reimbursement, unpaid_amount))
      credit = reimbursement.credits.build(creditable: creditable, amount: unpaid_amount)
      simulate ? credit.readonly! : credit.save!
      credit
    end

    def store_credit_params(category, reimbursement, unpaid_amount)
      {
        user: reimbursement.order.user,
        amount: unpaid_amount,
        category: category,
        created_by: Spree::StoreCredit.default_created_by,
        memo: "Refund for uncreditable payments on order #{reimbursement.order.number}",
        currency: reimbursement.order.currency
      }
    end

    # overwrite if you need options for the default reimbursement category
    def category_options(_reimbursement)
      {}
    end
  end
end
