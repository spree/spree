FactoryBot.define do
  factory :stock_reservation, class: Spree::StockReservation do
    quantity { 1 }
    expires_at { 10.minutes.from_now }

    transient do
      order { nil }
    end

    # Build the order first (with at least one line_item), then derive
    # stock_level from that line_item's variant so the three FKs reference the
    # same variant. Callers can override stock_level:/line_item:/order: to wire
    # up a specific scenario.
    after(:build) do |reservation, evaluator|
      if reservation.owner.nil?
        reservation.order = evaluator.order || create(:order_with_line_items, line_items_count: 1)
      end
      owner = reservation.owner

      if reservation.line_item.nil?
        reservation.line_item = owner.line_items.first ||
                                create(:line_item, order: owner.is_a?(Spree::Order) ? owner : nil, cart: owner.is_a?(Spree::Cart) ? owner : nil)
        owner.line_items.reload
      end

      reservation.stock_level ||= reservation.line_item.variant.stock_levels.first ||
                                 create(:stock_level, variant: reservation.line_item.variant)
    end

    trait :expired do
      expires_at { 1.minute.ago }
    end
  end
end
