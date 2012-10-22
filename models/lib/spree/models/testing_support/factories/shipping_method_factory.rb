FactoryGirl.define do
  factory :shipping_method, :class => Spree::ShippingMethod do
    zone { |a| Spree::Zone.find_by_name('GlobalZone') || a.association(:global_zone) }
    name 'UPS Ground'
    calculator { FactoryGirl.build(:calculator) }
  end

  factory :free_shipping_method, :class => Spree::ShippingMethod do
    zone { |a| Spree::Zone.find_by_name('GlobalZone') || a.association(:global_zone) }
    name 'UPS Ground'
    calculator { FactoryGirl.build(:no_amount_calculator) }
  end

  factory :shipping_method_with_category, :class => Spree::ShippingMethod do
    zone { |a| Spree::Zone.find_by_name('GlobalZone') || a.association(:global_zone) }
    name 'UPS Ground'
    match_none nil
    match_one nil
    match_all nil
    association(:shipping_category, :factory => :shipping_category)
    calculator { FactoryGirl.build(:calculator) }
  end
end
