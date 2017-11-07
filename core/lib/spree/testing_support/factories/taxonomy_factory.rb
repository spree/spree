FactoryBot.define do
  factory :taxonomy, class: Spree::Taxonomy do
    sequence(:name) { |n| "taxonomy_#{n}" }
  end
end
