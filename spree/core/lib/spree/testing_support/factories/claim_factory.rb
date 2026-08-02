FactoryBot.define do
  factory :claim, class: Spree::Claim do
    transient do
      line_items_count { 1 }
      send_replacement { false }
    end

    association(:order, factory: :shipped_order)
    store { order.store }
    status { Spree::Claim.default_status }
    claim_type { 'damaged' }
    memo { 'Arrived with a cracked screen' }

    after(:build) do |claim, evaluator|
      next if claim.claim_line_items.any?

      claim.order.line_items.limit(evaluator.line_items_count).each do |line_item|
        claim.claim_line_items.build(
          line_item: line_item,
          variant: line_item.variant,
          quantity: 1,
          send_replacement: evaluator.send_replacement,
          refund_amount: evaluator.send_replacement ? 0 : line_item.price,
          description: 'Screen is cracked'
        )
      end
    end

    factory :approved_claim do
      status { 'approved' }
      approved_at { Time.current }
    end
  end
end
