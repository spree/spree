FactoryGirl.define do
  factory :reimbursement_item, class: Spree::ReimbursementItem do
    association(:reimbursement, factory: :reimbursement)
    association(:inventory_unit, factory: :inventory_unit)

    factory :exchange_reimbursement_item do
      association(:exchange_variant, factory: :variant)
    end
  end
end
