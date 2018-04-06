class Spree::ReimbursementType::StoreCredit < Spree::ReimbursementType
  extend Spree::ReimbursementType::ReimbursementHelpers

  class << self
    def reimburse(reimbursement, return_items, simulate)
      unpaid_amount = return_items.sum(&:total).to_d.round(2, :down)
      payments = reimbursement.order.payments.completed.store_credits

      # Credit each store credit that was used on the order
      reimbursement_list, unpaid_amount = create_refunds(reimbursement, payments, unpaid_amount, simulate)

      # If there is any amount left to pay out to the customer, then create credit with that amount
      if unpaid_amount > 0.0
        reimbursement_list, _unpaid_amount = create_credits(reimbursement, unpaid_amount, simulate, reimbursement_list)
      end

      reimbursement_list
    end
  end
end
