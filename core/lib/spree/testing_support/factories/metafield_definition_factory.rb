FactoryBot.define do
  factory :metafield_definition, class: 'Spree::MetafieldDefinition' do
    namespace { 'custom' }
    sequence(:key) { |n| "custom_field_#{n}" }
    name { 'Custom Field' }
    metafield_type { 'Spree::Metafields::ShortText' }
    resource_type { 'Spree::Product' }
    display_on { 'both' }

    trait :front_end_only do
      display_on { 'front_end' }
    end

    trait :back_end_only do
      display_on { 'back_end' }
    end

    trait :short_text_field do
      metafield_type { 'Spree::Metafields::ShortText' }
      key { 'title' }
      name { 'Title' }
    end

    trait :long_text_field do
      metafield_type { 'Spree::Metafields::LongText' }
      key { 'description' }
      name { 'Description' }
    end

    trait :rich_text_field do
      metafield_type { 'Spree::Metafields::RichText' }
      key { 'content' }
      name { 'Content' }
    end

    trait :number_field do
      metafield_type { 'Spree::Metafields::Number' }
      key { 'priority' }
      name { 'Priority' }
    end

    trait :boolean_field do
      metafield_type { 'Spree::Metafields::Boolean' }
      key { 'featured' }
      name { 'Featured' }
    end

    trait :for_variant do
      resource_type { 'Spree::Variant' }
      key { 'variant_custom' }
      name { 'Variant Custom Field' }
    end

    trait :for_order do
      resource_type { 'Spree::Order' }
      key { 'order_notes' }
      name { 'Order Notes' }
    end

    trait :for_user do
      resource_type { Spree.user_class.name }
      key { 'user_preference' }
      name { 'User Preference' }
    end
  end
end
