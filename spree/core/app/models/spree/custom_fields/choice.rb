module Spree
  module CustomFields
    # One value from the definition's `choices`, or several when the
    # definition allows `multiple` (stored as a JSON array). The stored value
    # is the choice's `value`, so relabelling a choice changes no data.
    class Choice < Spree::CustomField
      before_validation :wrap_single_value, if: :multiple_choices?
      before_validation :unwrap_single_value, unless: :multiple_choices?

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
      # Choices are stored stripped, so values are too.
      def value=(raw)
        super(raw.is_a?(Array) ? raw.map { |choice| choice.to_s.strip }.uniq.to_json : raw.try(:strip) || raw)
      end

      # @return [String, Array<String>] an array when the definition allows several values
      # A one-item list written while the field allowed several reads as that
      # one value once it no longer does.
      def serialize_value
        multiple_choices? ? chosen_values : chosen_values.first
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

      # Parsed once per stored value; serializers and validations read it repeatedly.
      def stored_values
        return @stored_values if defined?(@stored_values_for) && @stored_values_for == value

        @stored_values_for = value
        @stored_values = parse_stored_values
      end

      def parse_stored_values
        return unless value.to_s.start_with?('[')

        parsed = JSON.parse(value)
        parsed if parsed.is_a?(Array)
      rescue JSON::ParserError
        nil
      end

      # Text such as a CSV cell lists the values the way {#text_value} joins
      # them; it is split only when it is not itself a choice and every part
      # is one, since a choice's own value may contain a comma.
      def wrap_single_value
        return if value.blank? || stored_values

        offered = custom_field_definition.choice_values
        parts = value.split(',').map(&:strip)
        self.value = offered.exclude?(value) && (parts - offered).empty? ? parts : [value]
      end

      # A single choice is stored bare, so it sorts and compares by its value
      # rather than as JSON text.
      def unwrap_single_value
        self.value = stored_values.first if stored_values&.one?
      end

      def value_must_follow_definition_rules
        if chosen_values.size > 1 && !multiple_choices?
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
