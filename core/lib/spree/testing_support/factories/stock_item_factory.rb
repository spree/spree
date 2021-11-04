FactoryBot.define do
  factory :stock_item, class: Spree::StockItem do
    backorderable { true }
    stock_location
    variant

    before(:create) do |stock_item|
      Spree::StockItem.find_by(
        variant: stock_item.variant,
        stock_location: stock_item.stock_location
      )&.destroy
    end

    after(:create) { |object| object.adjust_count_on_hand(10) }
  end
end
