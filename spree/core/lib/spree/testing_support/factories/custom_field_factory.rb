FactoryBot.define do
  factory :custom_field, aliases: [:metafield], class: 'Spree::CustomField' do
    value { 'test_value' }
    type { 'Spree::CustomFields::ShortText' }

    association :resource, factory: :product
    association :custom_field_definition

    trait :admin_only do
      association :custom_field_definition, :admin_only
    end

    trait :short_text do
      type { 'Spree::CustomFields::ShortText' }
      association :custom_field_definition, :short_text_field
      value { 'Short text value' }
    end

    trait :long_text do
      type { 'Spree::CustomFields::LongText' }
      association :custom_field_definition, :long_text_field
      value { 'This is a longer text value with more detailed information.' }
    end

    trait :number do
      type { 'Spree::CustomFields::Number' }
      association :custom_field_definition, :number_field
      value { 42 }
    end

    trait :rich_text do
      type { 'Spree::CustomFields::RichText' }
      association :custom_field_definition, :rich_text_field
      value { '<p>Rich text with <strong>formatting</strong></p>' }
    end

    trait :boolean do
      type { 'Spree::CustomFields::Boolean' }
      association :custom_field_definition, :boolean_field
      value { true }
    end

    trait :json do
      type { 'Spree::CustomFields::Json' }
      association :custom_field_definition, :json_field
      value { '{"key": "value"}' }
    end

    trait :for_variant do
      association :resource, factory: :variant
      association :custom_field_definition, :for_variant
    end

    trait :for_order do
      association :resource, factory: :order
      association :custom_field_definition, :for_order
    end

    trait :for_user do
      association :resource, factory: :user
      association :custom_field_definition, :for_user
    end
  end
end
