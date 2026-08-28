FactoryBot.define do
  factory :seller_requirement, class: Spree::SellerRequirement do
    store { Spree::Store.default || create(:store) }
    type { 'Spree::SellerRequirements::AcceptTerms' }
    active { true }
    required { true }

    factory :accept_terms_requirement, class: Spree::SellerRequirements::AcceptTerms do
      type { 'Spree::SellerRequirements::AcceptTerms' }
    end

    factory :billing_address_requirement, class: Spree::SellerRequirements::BillingAddress do
      type { 'Spree::SellerRequirements::BillingAddress' }
    end

    factory :returns_address_requirement, class: Spree::SellerRequirements::ReturnsAddress do
      type { 'Spree::SellerRequirements::ReturnsAddress' }
    end

    factory :complete_profile_requirement, class: Spree::SellerRequirements::CompleteProfile do
      type { 'Spree::SellerRequirements::CompleteProfile' }
    end

    factory :minimum_products_requirement, class: Spree::SellerRequirements::MinimumProducts do
      type { 'Spree::SellerRequirements::MinimumProducts' }
    end

    factory :required_custom_fields_requirement, class: Spree::SellerRequirements::RequiredCustomFields do
      type { 'Spree::SellerRequirements::RequiredCustomFields' }
    end

    # `allow_multiple?`, so the row's own name is the document it asks for.
    factory :policy_requirement, class: Spree::SellerRequirements::Policy do
      type { 'Spree::SellerRequirements::Policy' }
      name { 'Returns Policy' }
    end

    factory :attestation_requirement, class: Spree::SellerRequirements::Attestation do
      type { 'Spree::SellerRequirements::Attestation' }
      sequence(:name) { |n| "Confirm something #{n}" }
    end

    factory :operator_review_requirement, class: Spree::SellerRequirements::OperatorReview do
      type { 'Spree::SellerRequirements::OperatorReview' }
      sequence(:name) { |n| "Manual check #{n}" }
    end

    factory :document_requirement, class: Spree::SellerRequirements::Document do
      type { 'Spree::SellerRequirements::Document' }
      sequence(:name) { |n| "Document #{n}" }
    end
  end
end
