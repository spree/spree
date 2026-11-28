FactoryBot.define do
  # @deprecated Taxonomy is data-only in 6.0 and dropped in 6.3. Retained for the
  #   upgrade-path specs. The root category is created here because the model no
  #   longer manages one.
  factory :taxonomy, class: Spree::Taxonomy do
    sequence(:name) { |n| "taxonomy_#{n}" }
    store { Spree::Store.default }

    after(:create) do |taxonomy|
      root = Spree::Category.create!(taxonomy: taxonomy, store: taxonomy.store, name: taxonomy.name)
      # Published like any factory category, or it would hide every child.
      taxonomy.store.channels.active.publish_records(Spree::Category, root.id, publish_events: false)
      taxonomy.reload
    end
  end
end
