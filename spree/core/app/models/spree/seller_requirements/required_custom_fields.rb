# frozen_string_literal: true

module Spree
  module SellerRequirements
    # The seller has filled in the custom fields the marketplace asks for — a
    # VAT number, a company registration number, whatever this marketplace
    # needs. The operator defines the fields once as custom field definitions
    # on Spree::Seller and picks them here.
    #
    # The fields are joined rows, not keys in preferences: a definition that
    # is renamed keeps its id, and one that is deleted takes its row with it.
    # A stored `namespace.key` would survive both, match nothing, and count as
    # satisfied for every seller — a compliance check failing open.
    class RequiredCustomFields < Spree::SellerRequirement
      has_many :seller_requirement_custom_fields, class_name: 'Spree::SellerRequirementCustomField',
                                                  foreign_key: :seller_requirement_id,
                                                  dependent: :destroy, inverse_of: :seller_requirement
      has_many :custom_field_definitions, class_name: 'Spree::CustomFieldDefinition',
                                          through: :seller_requirement_custom_fields

      def self.additional_permitted_attributes
        [custom_field_definition_ids: []]
      end

      # The chosen definitions in prefixed form, read through the association
      # so a deleted one drops out rather than being echoed back at a client
      # that can no longer address it.
      #
      # @return [Array<String>]
      def custom_field_definition_prefixed_ids
        custom_field_definitions.pluck(:id).sort.map { |id| Spree::CustomFieldDefinition.prefixed_id_for(id) }
      end

      def met_by_seller?(seller)
        # `target` covers definitions assigned but not yet saved, matching
        # how the admin controller assigns before saving.
        definition_ids = if new_record?
                           seller_requirement_custom_fields.target.map(&:custom_field_definition_id)
                         else
                           custom_field_definitions.ids
                         end
        # A requirement naming no field asks nothing, and must not quietly
        # hold every seller back while the operator finishes configuring it.
        return true if definition_ids.empty?

        # `custom_fields` eager-loads its definitions, so this is one query
        # regardless of how many fields the operator asked for.
        answered = seller.custom_fields.filter_map do |field|
          field.custom_field_definition_id if field.value.present?
        end

        (definition_ids - answered).empty?
      end
    end
  end
end
