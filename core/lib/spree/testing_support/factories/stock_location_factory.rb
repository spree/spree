FactoryGirl.define do
  factory :stock_location, :class => Spree::StockLocation do
    name 'NY Warehouse'

    # associations:
    address
    after(:create) do |stock_location, evaluator|
      FactoryGirl.create_list(:stock_item, 2,
                              stock_location: stock_location)
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
