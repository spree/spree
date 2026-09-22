FactoryBot.define do
  factory :stock_transfer, class: Spree::StockTransfer do
    transient do
      # Units of one variant to move; zero opens an empty draft, which is what
      # a merchant sees before they add the first SKU. Enough source stock is
      # created for the in_transit trait to actually ship.
      quantity { 5 }
    end

    store { Spree::Store.default || create(:store) }
    source_location { create(:stock_location, store: store) }
    destination_location { create(:stock_location, store: store) }
    status { Spree::StockTransfer.default_status }
    reference { 'Restocking the Brooklyn shop' }

    # A draft with one line on it: what a merchant reaches by opening the
    # new-transfer screen and adding a SKU, and the start of every lifecycle
    # spec.
    after(:build) do |stock_transfer, evaluator|
      next if stock_transfer.items.any? || evaluator.quantity.to_i.zero?

      stock_transfer.items.build(variant: create(:variant), quantity_shipped: evaluator.quantity)
    end

    trait :ready_to_ship do
      status { 'ready_to_ship' }
    end

    # Shipped through the workflow, so the source's `shipped` movements exist
    # and its shelf is genuinely short — which is what the receive specs and
    # the cancel-in-transit specs measure against.
    trait :in_transit do
      after(:create) do |stock_transfer|
        stock_transfer.items.each do |item|
          stock_transfer.source_location.restock(item.variant, item.quantity_shipped)
        end

        Spree::StockTransfers::MarkInTransit.call(stock_transfer: stock_transfer)
        stock_transfer.reload
      end
    end

    trait :received do
      in_transit

      after(:create) do |stock_transfer|
        Spree::StockTransfers::Receive.call(stock_transfer: stock_transfer)
        stock_transfer.reload
      end
    end
  end

  factory :stock_transfer_item, class: Spree::StockTransferItem do
    stock_transfer
    variant
    quantity_shipped { 5 }
    quantity_received { 0 }
  end
end
