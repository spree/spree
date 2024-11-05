FactoryBot.define do
  factory :stock_transfer, class: Spree::StockTransfer do
    association :source_location, factory: :stock_location
    association :destination_location, factory: :stock_location
    number {}
    reference {}
    type {}
  end
end
