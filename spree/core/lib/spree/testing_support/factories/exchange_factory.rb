FactoryBot.define do
  factory :exchange, class: Spree::Exchange do
    transient do
      line_items_count { 1 }
      # The variant going out. Defaults to a fresh one on the same product so
      # the swap is meaningful without the caller building a catalog.
      replacement_variant { nil }
    end

    association(:order, factory: :shipped_order)
    store { order.store }
    stock_location { order.shipments.first&.stock_location || create(:stock_location) }
    status { Spree::Exchange.default_status }
    memo { 'Wrong size' }

    after(:build) do |exchange, evaluator|
      next if exchange.exchange_line_items.any?

      exchange.order.fulfillment_items.limit(evaluator.line_items_count).each do |fulfillment_item|
        replacement = evaluator.replacement_variant ||
                      create(:variant, product: fulfillment_item.variant.product)

        exchange.exchange_line_items.build(
          fulfillment_item: fulfillment_item,
          line_item: fulfillment_item.line_item,
          original_variant: fulfillment_item.variant,
          new_variant: replacement,
          quantity: 1
        )
      end
    end

    factory :approved_exchange do
      status { 'approved' }
      approved_at { Time.current }
    end

    factory :received_exchange do
      status { 'received' }
      approved_at { 1.day.ago }
      received_at { Time.current }

      after(:create) do |exchange|
        exchange.exchange_line_items.each do |line|
          line.update!(received_quantity: line.quantity)
        end
      end
    end
  end
end
