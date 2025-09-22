FactoryBot.define do
  factory :metafield_definition, class: 'Spree::MetafieldDefinition' do
    sequence(:key) { |n| "custom_field_#{n}" }
    name { 'Custom Field' }
    description { 'A custom field for storing additional data' }
    kind { 'short_text' }
    resource_type { 'Spree::Product' }
    display_on { 'both' }

    trait :front_end_only do
      display_on { 'front_end' }
    end

    trait :back_end_only do
      display_on { 'back_end' }
    end

    trait :short_text_field do
      kind { 'short_text' }
      key { 'title' }
      name { 'Title' }
      description { 'Short text field' }
    end

    trait :long_text_field do
      kind { 'long_text' }
      key { 'description' }
      name { 'Description' }
      description { 'Long text field for detailed information' }
    end

    trait :number_field do
      kind { 'number' }
      key { 'priority' }
      name { 'Priority' }
      description { 'Priority level as number' }
    end

    trait :boolean_field do
      kind { 'boolean' }
      key { 'featured' }
      name { 'Featured' }
      description { 'Whether item is featured' }
    end

    trait :json_field do
      kind { 'json' }
      key { 'settings' }
      name { 'Settings' }
      description { 'Configuration settings as JSON' }
    end

    trait :rich_text_field do
      kind { 'rich_text' }
      key { 'content' }
      name { 'Content' }
      description { 'Rich text content with formatting' }
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
