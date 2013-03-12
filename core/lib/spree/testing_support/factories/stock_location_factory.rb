FactoryGirl.define do
  factory :stock_location, :class => Spree::StockLocation do
    name 'NY Warehouse'
    active true

    address1 '1600 Pennsylvania Ave NW'
    city 'Washington'
    zipcode '20500'
    phone '(202) 456-1111'

    state  { |stock_location| stock_location.association(:state) }
    country  { |stock_location| stock_location.association(:country) }

    factory :stock_location_with_items do
      after(:create) do |stock_location, evaluator|
        Spree::Variant.skip_callback(:create, :after, :create_stock_items)
        stock_location.stock_items.create(variant: create(:variant), count_on_hand: 10)
        stock_location.stock_items.create(variant: create(:variant), count_on_hand: 20)
        Spree::Variant.set_callback(:create, :after, :create_stock_items)
      end
    end
  end
end
