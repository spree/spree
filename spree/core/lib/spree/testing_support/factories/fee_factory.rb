FactoryBot.define do
  factory :fee, class: Spree::Fee do
    association :order
    amount { 5.0 }
    label { 'Handling fee' }
    kind { 'handling' }
  end
end
