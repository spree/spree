FactoryBot.define do
  factory :tag, class: Spree::Tag do
    sequence(:name) { |n| "tag-#{n}" }
  end

  factory :tagging, class: Spree::Tagging do
    tag
    association :taggable, factory: :product
    context { 'tags' }
  end
end
