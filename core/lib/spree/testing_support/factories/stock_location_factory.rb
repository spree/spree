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
        # variant will add itself to all stock_locations in an after_create
        create(:variant)
        create(:variant)

        stock_location.stock_items.first.adjust_count_on_hand(10)
        stock_location.stock_items.second.adjust_count_on_hand(20)
      end
    end
  end

  # must use build()
  factory :stock_packer, :class => Spree::Stock::Packer do
    ignore do
      stock_location { build(:stock_location) }
      contents []
    end

    initialize_with { new(stock_location, contents) }
  end
end

