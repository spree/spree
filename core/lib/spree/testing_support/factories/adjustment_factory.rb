FactoryGirl.define do
  factory :adjustment, class: Spree::Adjustment do
    association(:adjustable, factory: :order)
    amount 100.0
    label 'Shipping'
    association(:source, factory: :shipment)
    eligible true
  end

  factory :line_item_adjustment, class: Spree::Adjustment do
    association(:adjustable, factory: :line_item)
    amount 10.0
    label 'VAT 5%'
    association(:source, factory: :tax_rate)
    eligible true
  end
end
