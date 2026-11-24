module StoreCreditRefundHelpers
  # Gives part of an order back as store credit, as a return, claim or
  # exchange does: a credit, recorded as refunds against the order's payments
  # (its shares, on a split checkout), oldest first.
  #
  # @return [Spree::StoreCredit]
  def give_back_as_store_credit(order, amount)
    credit = create(:store_credit, refunded_order: order, customer: order.customer, store: order.store, amount: amount)
    remaining = amount.to_d
    payments = order.grouped? ? order.payment_splits.order(:created_at).map(&:payment) : order.payments.order(:created_at).to_a

    payments.select(&:completed?).each do |payment|
      available = order.grouped? ? order.payment_split_for(payment).refundable_amount : payment.reload.credit_allowed
      share = [available, remaining].min
      next unless share.positive?

      result = Spree.refund_create_workflow.call(payment: payment, order: order, amount: share, store_credit: credit)
      raise result.error.value.to_s if result.failure?

      remaining -= share
    end

    credit
  end
end

RSpec.configure do |config|
  config.include StoreCreditRefundHelpers
end
