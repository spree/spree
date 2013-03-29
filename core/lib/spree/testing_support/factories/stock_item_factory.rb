FactoryGirl.define do
  factory :stock_item, :class => Spree::StockItem do
    # associations:
    variant
    stock_location

    after(:create) {|object| object.adjust_count_on_hand(10) }
  end
end
