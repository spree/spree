FactoryGirl.define do
  factory :shipping_method, :class => Spree::ShippingMethod do
    zone { |a| Spree::Zone.find_by_name('GlobalZone') || a.association(:global_zone) }
    name 'UPS Ground'
    calculator { |sm| Factory(:calculator, :calculable_id => sm.object_id, :calculable_type => 'Spree::ShippingMethod') }
  end

  factory :free_shipping_method, :class => Spree::ShippingMethod do
    zone { |a| Spree::Zone.find_by_name('GlobalZone') || a.association(:global_zone) }
    name 'UPS Ground'
    calculator { |sm| Factory(:no_amount_calculator, :calculable_id => sm.object_id, :calculable_type => 'Spree::ShippingMethod') }
  end

  factory :shipping_method_with_category, :class => Spree::ShippingMethod do
    zone { |a| Spree::Zone.find_by_name('GlobalZone') || a.association(:global_zone) }
    name 'UPS Ground'
    calculator { |sm| Factory(:calculator, :calculable_id => sm.object_id, :calculable_type => 'Spree::ShippingMethod') }
    match_none nil
    match_one nil
    match_all nil
    association(:shipping_category, :factory => :shipping_category)
  end
end
