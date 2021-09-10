FactoryBot.define do
  factory :relation, class: Spree::Relation do
    association :relatable, factory: :product
    association :related_to, factory: :product
    relation_type
  end
end
