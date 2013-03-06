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

    # associations:
    after(:create) do |stock_location, evaluator|
      FactoryGirl.create_list(:stock_item, 2,
                              stock_location: stock_location)
    end
  end
end
