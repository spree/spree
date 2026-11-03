# frozen_string_literal: true

module Spree
  class CustomFieldDefinition
    # The `validations` rules a definition places on its values. Which rules
    # apply is up to the field type (`supported_validation_rules`); every type
    # takes `required`, which the server leaves to the forms that edit the
    # value. Values are checked against the rules in Spree::CustomField, on
    # new writes only.
    module ValidationRules
      extend ActiveSupport::Concern

      BOUND_RULES = %w[min max].freeze
      BOOLEAN_RULES = %w[required multiple].freeze

      included do
        before_validation :normalize_validations
        validate :validations_must_apply_to_field_type
        validate :sortable_must_be_single_choice
      end

      # Accepts permitted request params as well as a plain hash.
      def validations=(rules)
        super(rules.respond_to?(:permitted?) ? rules.to_h : rules)
      end

      # @return [Hash{String => Object}] the rules, empty when there are none
      def validation_rules
        rules = self[:validations]
        rules.is_a?(Hash) ? rules : {}
      end

      def required?
        validation_rules['required'] == true
      end

      def multiple_choices?
        validation_rules['multiple'] == true
      end

      # @return [Array<Hash{String => String}>] a `choice` field's `value` / `label` pairs, in order
      def choices
        Array(validation_rules['choices']).grep(Hash)
      end

      # @return [Array<String>] the values a `choice` field may store
      def choice_values
        choices.map { |choice| choice['value'] }
      end

      private

      # Bounds are stored in the type's canonical form (a UTC date-time, a
      # whole character count), so values compare against them directly. An
      # unparseable bound is left as sent for the validation to name.
      def normalize_validations
        rules = self[:validations]
        return self.validations = nil if rules.blank?
        return unless rules.is_a?(Hash)

        rules = rules.deep_stringify_keys.compact
        BOUND_RULES.each do |rule|
          next unless rules.key?(rule) && field_type_class

          bound = field_type_class.normalize_validation_bound(rules[rule], store: store)
          rules[rule] = bound unless bound.nil?
        end
        rules['choices'] = rules['choices'].map { |choice| normalize_choice(choice) } if rules['choices'].is_a?(Array)

        self.validations = rules
      end

      def normalize_choice(choice)
        return choice unless choice.is_a?(Hash)

        value = choice['value'].to_s.strip
        label = choice['label'].to_s.strip
        { 'value' => value, 'label' => label.presence || value }
      end

      def validations_must_apply_to_field_type
        rules = self[:validations]
        return add_validations_error(:validations_not_an_object) unless rules.nil? || rules.is_a?(Hash)
        return if field_type_class.nil?

        rules ||= {}

        unknown = rules.keys - ['required', *field_type_class.supported_validation_rules]
        return add_validations_error(:validation_unknown_rule, rules: unknown.join(', ')) if unknown.any?

        validate_boolean_rules(rules)
        validate_bound_rules(rules)
        validate_choices_rule(rules) if field_type_class.supported_validation_rules.include?('choices')
      end

      def validate_boolean_rules(rules)
        (BOOLEAN_RULES & rules.keys).each do |rule|
          add_validations_error(:validation_not_a_boolean, rule: rule) unless [true, false].include?(rules[rule])
        end
      end

      def validate_bound_rules(rules)
        bounds = rules.slice(*BOUND_RULES)
        invalid = bounds.select { |_rule, bound| field_type_class.normalize_validation_bound(bound, store: store) != bound }
        invalid.each_key { |rule| add_validations_error(:validation_invalid_bound, rule: rule) }
        return if invalid.any? || bounds.size < 2

        add_validations_error(:validation_min_above_max) if bounds['min'] > bounds['max']
      end

      def validate_choices_rule(rules)
        choices = rules['choices']
        return add_validations_error(:validation_choices_required) if choices.blank?
        return add_validations_error(:validation_choices_invalid) unless choices.is_a?(Array) && choices.all? { |choice| choice.is_a?(Hash) && choice['value'].present? }

        add_validations_error(:validation_choices_not_unique) if choice_values.uniq.size != choice_values.size
      end

      # Several stored values have no single sort position.
      def sortable_must_be_single_choice
        return unless sortable? && multiple_choices?

        errors.add(:sortable, :single_choice_only, message: I18n.t('spree.errors.messages.custom_field_sortable_single_choice_only'))
      end

      def add_validations_error(type, **options)
        errors.add(:validations, type, **options, message: I18n.t("spree.errors.messages.custom_field_#{type}", **options))
      end
    end
  end
end
