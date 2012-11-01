FactoryGirl.define do
  factory :adjustment, :class => Spree::Adjustment do
    adjustable { FactoryGirl.create(:order) }
    amount '100.0'
    label 'Shipping'
    source { FactoryGirl.create(:shipment) }
    eligible true
  end
  factory :line_item_adjustment, :class => Spree::Adjustment do
    adjustable { FactoryGirl.create(:line_item) }
    amount '10.0'
    label 'VAT 5%'
    source { FactoryGirl.create(:tax_rate) }
    eligible true
  end
end
