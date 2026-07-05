FactoryBot.define do
  factory :stock_reservation, class: Spree::StockReservation do
    quantity { 1 }
    expires_at { 10.minutes.from_now }

    transient do
      order { nil }
    end

    # Build the order first (with at least one line_item), then derive
    # stock_item from that line_item's variant so the three FKs reference the
    # same variant. Callers can override stock_item:/line_item:/order: to wire
    # up a specific scenario.
    after(:build) do |reservation, evaluator|
      reservation.order ||= evaluator.order || create(:order_with_line_items, line_items_count: 1)

      if reservation.line_item.nil?
        reservation.line_item = reservation.order.line_items.first ||
                                create(:line_item, order: reservation.order)
        reservation.order.line_items.reload
      end

      reservation.stock_item ||= reservation.line_item.variant.stock_items.first ||
                                 create(:stock_item, variant: reservation.line_item.variant)
    end

    trait :expired do
      expires_at { 1.minute.ago }
    end
  end
end
