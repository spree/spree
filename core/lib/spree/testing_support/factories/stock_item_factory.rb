FactoryBot.define do
  factory :stock_item, class: Spree::StockItem do
    backorderable { true }
    stock_location
    variant

    before(:create) do |stock_item|
      # Use really_destroy! (hard delete) to avoid unique index conflicts
      # with deleted_at timestamps in MySQL when tests run quickly
      Spree::StockItem.find_by(
        variant: stock_item.variant,
        stock_location: stock_item.stock_location
      )&.really_destroy!
    end

    transient do
      adjust_count_on_hand { true }
    end

    after(:create) { |object, evaluator| object.adjust_count_on_hand(10) if evaluator.adjust_count_on_hand }
  end
end
