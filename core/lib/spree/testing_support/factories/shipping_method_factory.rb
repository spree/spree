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
    calculator { FactoryGirl.build(:calculator) }
    after(:create) do |shipping_method, evaluator|
      shipping_method.shipping_categories << create(:shipping_category)
    end
  end
end
