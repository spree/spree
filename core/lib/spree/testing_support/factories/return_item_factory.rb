FactoryGirl.define do
  factory :return_item, class: Spree::ReturnItem do
    association(:inventory_unit, factory: :inventory_unit, state: 'shipped')
    association(:return_authorization, factory: :return_authorization)

    additional_tax_total 0
    included_tax_total 0

    factory :exchange_return_item do
      association(:exchange_variant, factory: :variant)
    end
  end
end
