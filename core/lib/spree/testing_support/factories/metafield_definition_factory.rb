FactoryBot.define do
  factory :metafield_definition, class: 'Spree::MetafieldDefinition' do
    namespace { 'custom' }
    sequence(:key) { |n| "custom_field_#{n}" }
    name { 'Custom Field' }
    type { 'Spree::MetafieldDefinitions::ShortText' }
    resource_type { 'Spree::Product' }
    display_on { 'both' }

    trait :front_end_only do
      display_on { 'front_end' }
    end

    trait :back_end_only do
      display_on { 'back_end' }
    end

    trait :short_text_field do
      type { 'Spree::MetafieldDefinitions::ShortText' }
      key { 'title' }
      name { 'Title' }
    end

    trait :long_text_field do
      type { 'Spree::MetafieldDefinitions::LongText' }
      key { 'description' }
      name { 'Description' }
    end

    trait :number_field do
      type { 'Spree::MetafieldDefinitions::Number' }
      key { 'priority' }
      name { 'Priority' }
    end

    trait :boolean_field do
      type { 'Spree::MetafieldDefinitions::Boolean' }
      key { 'featured' }
      name { 'Featured' }
    end

    trait :json_field do
      type { 'Spree::MetafieldDefinitions::Json' }
      key { 'settings' }
      name { 'Settings' }
    end

    trait :rich_text_field do
      type { 'Spree::MetafieldDefinitions::RichText' }
      key { 'content' }
      name { 'Content' }
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
      resource_type { 'Spree::User' }
      key { 'user_preference' }
      name { 'User Preference' }
    end
  end
end
