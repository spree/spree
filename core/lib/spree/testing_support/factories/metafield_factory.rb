FactoryBot.define do
  factory :metafield, class: 'Spree::Metafield' do
    value { 'test_value' }
    type { 'Spree::Metafields::ShortText' }

    association :resource, factory: :product
    association :metafield_definition

    trait :front_end_only do
      association :metafield_definition, :front_end_only
    end

    trait :back_end_only do
      association :metafield_definition, :back_end_only
    end

    trait :short_text do
      type { 'Spree::Metafields::ShortText' }
      association :metafield_definition, :short_text_field
      value { 'Short text value' }
    end

    trait :long_text do
      type { 'Spree::Metafields::LongText' }
      association :metafield_definition, :long_text_field
      value { 'This is a longer text value with more detailed information.' }
    end

    trait :number do
      type { 'Spree::Metafields::Number' }
      association :metafield_definition, :number_field
      value { 42 }
    end

    trait :rich_text do
      type { 'Spree::Metafields::RichText' }
      association :metafield_definition, :rich_text_field
      value { '<p>Rich text with <strong>formatting</strong></p>' }
    end

    trait :boolean do
      type { 'Spree::Metafields::Boolean' }
      association :metafield_definition, :boolean_field
      value { true }
    end

    trait :for_variant do
      association :resource, factory: :variant
      association :metafield_definition, :for_variant
    end

    trait :for_order do
      association :resource, factory: :order
      association :metafield_definition, :for_order
    end

    trait :for_user do
      association :resource, factory: :user
      association :metafield_definition, :for_user
    end
  end
end
