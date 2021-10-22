FactoryBot.define do
  factory :stock_transfer, class: Spree::StockTransfer do
    destination_location {}
    number {}
    reference {}
    source_location {}
    type {}
  end
end
