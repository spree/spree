FactoryGirl.define do
  factory :return_item, class: Spree::ReturnItem do
    association(:inventory_unit, factory: :inventory_unit)
    association(:return_authorization, factory: :return_authorization)
  end
end
