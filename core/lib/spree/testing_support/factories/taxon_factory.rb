FactoryBot.define do
  factory :taxon, class: Spree::Taxon do
    sequence(:name) { |n| "taxon_#{n}" }
    association(:taxonomy, strategy: :create)
    parent_id { taxonomy.root.id }
  end
end
