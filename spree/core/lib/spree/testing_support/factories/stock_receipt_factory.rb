FactoryBot.define do
  # The record only. Building one here books nothing: line totals and stock
  # movements are written by the receive workflows, which is what a spec that
  # needs a real delivery should call.
  factory :stock_receipt, class: Spree::StockReceipt do
    transient do
      quantity_accepted { nil }
      quantity_rejected { 0 }
      rejection_reason { nil }
    end

    receivable { create(:purchase_order, :ordered) }
    store { receivable.store }
    received_at { Time.current }
    reference { 'Delivery note 4471' }

    after(:build) do |receipt, evaluator|
      next if receipt.items.any?

      receipt.receivable.items.each do |line|
        receipt.items.build(
          line: line,
          quantity_accepted: evaluator.quantity_accepted || line.outstanding,
          quantity_rejected: evaluator.quantity_rejected,
          rejection_reason: evaluator.rejection_reason
        )
      end
    end
  end

  factory :stock_receipt_item, class: Spree::StockReceiptItem do
    stock_receipt
    line { create(:purchase_order_item) }
    quantity_accepted { 5 }
    quantity_rejected { 0 }
  end
end
