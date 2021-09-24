FactoryBot.define do
  factory :relation_type, class: Spree::RelationType do
    name       { generate(:random_string) }
    applies_to { 'Spree::Product' }
  end
end
