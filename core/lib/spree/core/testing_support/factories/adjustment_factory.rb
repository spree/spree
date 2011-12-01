FactoryGirl.define do
  factory :adjustment, :class => Spree::Adjustment do
    adjustable { Factory(:order) }
    amount '100.0'
    label 'Shipping'
    source { Factory(:shipment) }
    eligible true
  end
  factory :line_item_adjustment, :class => Spree::Adjustment do
    adjustable { Factory(:line_item) }
    amount '10.0'
    label 'VAT 5%'
    source { Factory(:tax_rate) }
    eligible true
  end
end
