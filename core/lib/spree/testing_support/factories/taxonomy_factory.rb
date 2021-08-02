FactoryBot.define do
  factory :taxonomy, class: Spree::Taxonomy do
    sequence(:name) { |n| "taxonomy_#{n}" }
    store { Spree::Store.default }
  end
end
