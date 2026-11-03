FactoryBot.define do
  factory :custom_field_definition, aliases: [:metafield_definition], class: 'Spree::CustomFieldDefinition' do
    store { Spree::Store.default || create(:store) }
    namespace { 'custom' }
    sequence(:key) { |n| "custom_field_#{n}" }
    label { 'Custom Field' }
    field_type { 'Spree::CustomFields::ShortText' }
    resource_type { 'Spree::Product' }
    storefront_visible { true }
    searchable { false }
    sortable { false }

    trait :admin_only do
      storefront_visible { false }
    end

    trait :short_text_field do
      field_type { 'Spree::CustomFields::ShortText' }
      key { 'title' }
      label { 'Title' }
    end

    trait :long_text_field do
      field_type { 'Spree::CustomFields::LongText' }
      key { 'description' }
      label { 'Description' }
    end

    trait :rich_text_field do
      field_type { 'Spree::CustomFields::RichText' }
      key { 'content' }
      label { 'Content' }
    end

    trait :number_field do
      field_type { 'Spree::CustomFields::Number' }
      key { 'priority' }
      label { 'Priority' }
    end

    trait :boolean_field do
      field_type { 'Spree::CustomFields::Boolean' }
      key { 'featured' }
      label { 'Featured' }
    end

    trait :json_field do
      field_type { 'Spree::CustomFields::Json' }
      key { 'metadata' }
      label { 'Metadata' }
    end

    trait :date_field do
      field_type { 'Spree::CustomFields::Date' }
      key { 'delivery_date' }
      label { 'Delivery date' }
    end

    trait :date_time_field do
      field_type { 'Spree::CustomFields::DateTime' }
      key { 'pickup_at' }
      label { 'Pickup at' }
    end

    trait :choice_field do
      field_type { 'Spree::CustomFields::Choice' }
      key { 'zone' }
      label { 'Zone' }
      validations { { choices: [{ value: 'a', label: 'Zone A' }, { value: 'b', label: 'Zone B' }, { value: 'c', label: 'Zone C' }] } }
    end

    trait :multiple_choice_field do
      choice_field
      validations { { choices: [{ value: 'a', label: 'Zone A' }, { value: 'b', label: 'Zone B' }, { value: 'c', label: 'Zone C' }], multiple: true } }
    end

    trait :searchable do
      searchable { true }
    end

    trait :sortable do
      sortable { true }
    end

    trait :for_variant do
      resource_type { 'Spree::Variant' }
      key { 'variant_custom' }
      label { 'Variant Custom Field' }
    end

    trait :for_order do
      resource_type { 'Spree::Order' }
      key { 'order_notes' }
      label { 'Order Notes' }
    end

    trait :for_user do
      resource_type { Spree.customer_class.name }
      key { 'user_preference' }
      label { 'User Preference' }
    end
  end
end
