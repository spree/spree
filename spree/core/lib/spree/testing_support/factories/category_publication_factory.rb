FactoryBot.define do
  factory :category_publication, class: Spree::CategoryPublication do
    category factory: [:category, :unpublished]
    channel { category&.store&.default_channel || association(:channel) }
  end
end
