# frozen_string_literal: true

module Spree
  # Joins a requirement to a custom field definition it asks the seller to
  # fill in. A concrete row rather than a key in preferences: a definition
  # that is renamed keeps its id, and one that is deleted takes this row with
  # it — a stored key would survive both and quietly satisfy every seller.
  class SellerRequirementCustomField < Spree.base_class
    belongs_to :seller_requirement, class_name: 'Spree::SellerRequirement'
    belongs_to :custom_field_definition, class_name: 'Spree::CustomFieldDefinition'

    validates :custom_field_definition_id, uniqueness: { scope: :seller_requirement_id }, allow_nil: true
    validate :definition_must_describe_a_seller
    validate :definition_must_belong_to_the_same_store

    private

    # A definition for products or orders asks the seller for something they
    # have no field to answer with, so the requirement could never be met.
    def definition_must_describe_a_seller
      return if custom_field_definition.nil?
      return if custom_field_definition.resource_type == Spree::Seller.to_s

      errors.add(:custom_field_definition, :invalid,
                 message: Spree.t('seller_requirements.custom_field_not_for_sellers',
                                  default: 'must be a custom field defined for sellers'))
    end

    # Both sides are store-owned, so a marketplace can only ask its sellers
    # for fields it defined itself.
    def definition_must_belong_to_the_same_store
      return if custom_field_definition.nil? || seller_requirement.nil?
      return if custom_field_definition.store_id == seller_requirement.store_id

      errors.add(:custom_field_definition, :must_belong_to_same_store)
    end
  end
end
