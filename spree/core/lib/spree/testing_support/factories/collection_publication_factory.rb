FactoryBot.define do
  factory :collection_publication, class: Spree::CollectionPublication do
    collection
    channel { collection&.store&.default_channel || association(:channel) }
  end
end
