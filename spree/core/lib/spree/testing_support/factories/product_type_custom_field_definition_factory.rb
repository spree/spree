FactoryBot.define do
  factory :product_type_custom_field_definition, class: Spree::ProductTypeCustomFieldDefinition do
    product_type
    custom_field_definition

    trait :required do
      required { true }
    end
  end
end
