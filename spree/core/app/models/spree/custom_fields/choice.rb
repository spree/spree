module Spree
  module CustomFields
    # One value from the definition's `choices`, or several when the
    # definition allows `multiple` (stored as a JSON array). The stored value
    # is the choice's `value`, so relabelling a choice changes no data.
    class Choice < Spree::CustomField
      before_validation :wrap_single_value, if: :multiple_choices?

      def self.searchable?
        true
      end

      # Single choices only: a definition that allows several values is
      # refused `sortable` (CustomFieldDefinition::ValidationRules).
      def self.sortable?
        true
      end

      def self.supported_validation_rules
        %w[choices multiple]
      end

      # @param raw [String, Array<String>, nil]
      def value=(raw)
        super(raw.is_a?(Array) ? raw.map(&:to_s).to_json : raw)
      end

      # @return [String, Array<String>] an array when the definition allows several values
      def serialize_value
        multiple_choices? ? chosen_values : value
      end

      def text_value
        chosen_values.join(', ')
      end

      # @return [Array<String>]
      def chosen_values
        stored_values || [value].compact
      end

      private

      def multiple_choices?
        custom_field_definition&.multiple_choices?
      end

      def stored_values
        return unless value.to_s.start_with?('[')

        parsed = JSON.parse(value)
        parsed if parsed.is_a?(Array)
      rescue JSON::ParserError
        nil
      end

      def wrap_single_value
        self.value = [value] if value.present? && stored_values.nil?
      end

      def value_must_follow_definition_rules
        if stored_values && !multiple_choices?
          return errors.add(:value, :single_choice_only, message: I18n.t('spree.errors.messages.custom_field_single_choice_only'))
        end
        return errors.add(:value, :blank) if chosen_values.empty?

        offered = custom_field_definition.choice_values
        (chosen_values - offered).each do |choice|
          errors.add(:value, :choice_not_offered, value: choice,
                     message: I18n.t('spree.errors.messages.custom_field_choice_not_offered', value: choice))
        end
      end
    end
  end
end
