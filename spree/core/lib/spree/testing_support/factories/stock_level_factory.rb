FactoryBot.define do
  # :stock_item is the pre-6.0 name, kept for one release so host-app factories
  # and specs written against it keep working.
  factory :stock_level, class: Spree::StockLevel, aliases: [:stock_item] do
    backorderable { true }
    stock_location
    variant

    before(:create) do |stock_level|
      # Use really_destroy! (hard delete) to avoid unique index conflicts
      # with deleted_at timestamps in MySQL when tests run quickly
      Spree::StockLevel.where(
        variant_id: stock_level.variant_id,
        stock_location_id: stock_level.stock_location_id
      ).delete_all
    end

    transient do
      adjust_count_on_hand { true }
    end

    after(:create) { |object, evaluator| object.adjust_count_on_hand(10) if evaluator.adjust_count_on_hand }
  end
end
