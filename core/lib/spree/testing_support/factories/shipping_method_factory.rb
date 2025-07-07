FactoryBot.define do
  factory :base_shipping_method, class: Spree::ShippingMethod do
    zones      { |_a| [Spree::Zone.global] }
    name       { 'UPS Ground' }
    code       { 'UPS_GROUND' }
    display_on { 'both' }

    before(:create) do |shipping_method, _evaluator|
      if shipping_method.shipping_categories.empty?
        shipping_method.shipping_categories << (Spree::ShippingCategory.first || create(:shipping_category))
      end
    end

    factory :shipping_method, class: Spree::ShippingMethod do
      association(:calculator, factory: :shipping_calculator, strategy: :build)
    end

    factory :free_shipping_method, class: Spree::ShippingMethod do
      association(:calculator, factory: :shipping_no_amount_calculator, strategy: :build)
    end

    factory :digital_shipping_method, class: Spree::ShippingMethod do
      association(:calculator, factory: :digital_shipping_calculator, strategy: :build)

      before(:create) do |shipping_method|
        shipping_method.shipping_categories.delete_all
        shipping_method.shipping_categories << create(:digital_shipping_category)
      end
    end
  end
end
