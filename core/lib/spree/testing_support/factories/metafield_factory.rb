FactoryBot.define do
  factory :metafield, class: 'Spree::Metafield' do
    value { 'test_value' }
    
    association :owner, factory: :product
    association :metafield_definition
    
    trait :front_end_only do
      association :metafield_definition, :front_end_only
    end

    trait :back_end_only do
      association :metafield_definition, :back_end_only
    end
    
    trait :short_text do
      association :metafield_definition, :short_text_field
      value { 'Short text value' }
    end

    trait :long_text do
      association :metafield_definition, :long_text_field
      value { 'This is a longer text value with more detailed information.' }
    end

    trait :number do
      association :metafield_definition, :number_field
      value { 42 }
    end

    trait :rich_text do
      association :metafield_definition, :rich_text_field
      value { '<p>Rich text with <strong>formatting</strong></p>' }
    end
    
    trait :boolean do
      association :metafield_definition, :boolean_field
      value { true }
    end
    
    trait :json do
      association :metafield_definition, :json_field
      value { { 'key' => 'value' } }
    end
    
    trait :for_variant do
      association :owner, factory: :variant
      association :metafield_definition, :for_variant
    end
    
    trait :for_order do
      association :owner, factory: :order
      association :metafield_definition, :for_order
    end
    
    trait :for_user do
      association :owner, factory: :user
      association :metafield_definition, :for_user
    end
  end
end