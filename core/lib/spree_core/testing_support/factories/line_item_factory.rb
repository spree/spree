FactoryGirl.define do
  factory :line_item do
    quantity 1
    price { BigDecimal.new("10.00") }

    # associations:
    association(:order, :factory => :order)
    association(:variant, :factory => :variant)
  end
end