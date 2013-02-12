FactoryGirl.define do
  factory :stock_item, :class => Spree::StockItem do
    count_on_hand 10

    # associations:
    variant
  end
end
