module Spree
  module CollectionRules
    # Products whose custom field matches the value. Only definitions marked
    # `collection_condition` can be used. Text fields compare as text, number
    # fields as numbers, boolean fields by equality.
    class CustomField < Spree::CollectionRule
      TEXT_POLICIES = %w[is_equal_to is_not_equal_to contains does_not_contain starts_with ends_with].freeze
      NUMBER_POLICIES = %w[is_equal_to is_not_equal_to greater_than less_than].freeze
      BOOLEAN_POLICIES = %w[is_equal_to is_not_equal_to].freeze

      preference :custom_field_definition_id, :string

      validate :definition_must_be_a_collection_condition, if: :collection
      validate :match_policy_must_suit_field_type, if: :definition

      def self.match_policies
        (TEXT_POLICIES + NUMBER_POLICIES).uniq
      end

      # The definition, named by its prefixed id and looked up in the store.
      #
      # @return [Spree::CustomFieldDefinition, nil]
      def definition
        return if collection.nil? || preferred_custom_field_definition_id.blank?

        @definition = nil if @definition && @definition.prefixed_id != preferred_custom_field_definition_id
        @definition ||= store.custom_field_definitions.
                        where(resource_type: 'Spree::Product', collection_condition: true).
                        find_by_prefix_id(preferred_custom_field_definition_id)
      end

      def apply(scope)
        return scope.none if definition.nil?

        fields = Spree::CustomField.where(resource_type: 'Spree::Product', custom_field_definition_id: definition.id)
        product_ids = if definition.field_type == 'number'
                        number_matches(fields.where(resource_id: scope.select(:id)))
                      else
                        fields.where(value_condition).select(:resource_id)
                      end
        match(scope, Spree::Product.where(id: product_ids))
      end

      private

      # Stored values are text, and a blank or stale one would make a SQL cast
      # fail for every row, so numbers are compared here.
      def number_matches(fields)
        target = decimal(value)
        return [] if target.nil?

        fields.pluck(:resource_id, :value).filter_map do |product_id, stored|
          number = decimal(stored)
          next if number.nil?

          product_id if (match_policy == 'greater_than' && number > target) ||
                        (match_policy == 'less_than' && number < target) ||
                        (match_policy.in?(%w[is_equal_to is_not_equal_to]) && number == target)
        end
      end

      def decimal(text)
        BigDecimal(text.to_s)
      rescue ArgumentError
        nil
      end

      def value_condition
        column = Spree::CustomField.arel_table[:value]

        case definition.field_type
        when 'boolean'
          column.eq(ActiveModel::Type::Boolean.new.cast(value).to_s)
        else
          column.matches(like_pattern, '\\')
        end
      end

      def definition_must_be_a_collection_condition
        errors.add(:preferences, :invalid) if definition.nil?
      end

      def match_policy_must_suit_field_type
        allowed = case definition.field_type
                  when 'number' then NUMBER_POLICIES
                  when 'boolean' then BOOLEAN_POLICIES
                  else TEXT_POLICIES
                  end
        errors.add(:match_policy, :inclusion) unless allowed.include?(match_policy)
        errors.add(:value, :not_a_number) if definition.field_type == 'number' && !value.to_s.match?(/\A-?\d+(\.\d+)?\z/)
      end
    end
  end
end
