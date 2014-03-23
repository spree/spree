FactoryGirl.define do
  factory :base_shipping_method, class: Spree::ShippingMethod do
    zones { |a| [Spree::Zone.global] }
    name 'UPS Ground'

    before(:create) do |shipping_method, evaluator|
      if shipping_method.shipping_categories.empty?
        shipping_method.shipping_categories << (Spree::ShippingCategory.first || create(:shipping_category))
      end
    end

    factory :shipping_method, class: Spree::ShippingMethod do
      association(:calculator, factory: :calculator, strategy: :build)
    end

    factory :free_shipping_method, class: Spree::ShippingMethod do
      association(:calculator, factory: :no_amount_calculator, strategy: :build)
    end
  end
end
