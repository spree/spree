FactoryBot.define do
  # @deprecated Taxonomy is data-only in 6.0 and dropped in 6.1. Retained for the
  #   upgrade-path specs. The root category is created here because the model no
  #   longer manages one.
  factory :taxonomy, class: Spree::Taxonomy do
    sequence(:name) { |n| "taxonomy_#{n}" }
    store { Spree::Store.default }

    after(:create) do |taxonomy|
      Spree::Category.create!(taxonomy: taxonomy, store: taxonomy.store, name: taxonomy.name)
      taxonomy.reload
    end
  end
end
