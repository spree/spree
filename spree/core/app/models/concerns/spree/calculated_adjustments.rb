module Spree
  module CalculatedAdjustments
    extend ActiveSupport::Concern

    included do
      has_one :calculator, class_name: 'Spree::Calculator', as: :calculable, inverse_of: :calculable, dependent: :destroy, autosave: true
      accepts_nested_attributes_for :calculator
      validates :calculator, presence: true
      delegate :compute, to: :calculator

      scope :with_calculator, ->(calculator) { joins(:calculator).where(calculator: { type: calculator.to_s }) }

      def self.calculators
        spree_calculators.send model_name_without_spree_namespace
      end

      # The public API shorthand (`'flat_rate'`), never the Ruby class name.
      def calculator_type
        calculator.class.api_type if calculator
      end

      # Takes the public API shorthand (`'flat_rate'`), resolved against this
      # parent's registered calculators — so a CreateAdjustment can't be
      # assigned a shipping-only calculator just by knowing its name, and
      # nothing user-supplied ever reaches `constantize`.
      def calculator_type=(calculator_type)
        return if calculator_type.blank?

        klass = registered_calculator_class(calculator_type)
        self.calculator = klass.new if klass && !calculator.instance_of?(klass)
      end

      # API v3 writer for the `calculator: { type:, preferences: {} }`
      # payload. A type the registry does not list is refused like a setting
      # that does not match (`/calculator/type`); preferences are checked
      # against the calculator's schema and written through its typed writers.
      #
      # @param attrs [Hash, ActionController::Parameters, nil]
      # @param pointer [String] where the calculator sits in the request
      # @raise [Spree::Preferences::InvalidPreferences] for a type the registry does not list, or
      #   preferences that do not match its schema
      # @return [void]
      def assign_calculator_attributes(attrs, pointer: '/calculator')
        return if attrs.nil?

        attrs = attrs.to_h.with_indifferent_access
        type = attrs[:type].to_s
        target = calculator
        if type.present? && calculator&.class&.api_type != type
          klass = registered_calculator_class(type)
          unless klass
            raise Spree::Preferences::InvalidPreferences.new(
              [{ pointer: '/type', message: I18n.t('spree.errors.messages.unknown_calculator_type', type: type) }], prefix: pointer
            )
          end

          target = klass.new
        end

        if attrs[:preferences].present?
          # Preferences sent without a type land on the default calculator
          # rather than on nothing, for a model that has one.
          target ||= default_calculator if respond_to?(:default_calculator, true)
          target&.assign_preferences(attrs[:preferences], pointer: "#{pointer}/preferences")
        end

        # Attached only once its settings are accepted: on a saved owner,
        # assigning a has_one replaces the stored calculator immediately.
        self.calculator = target unless target.equal?(calculator)
      end

      private

      # The registered calculator for an API shorthand, resolved from the
      # registry entry's own name: nothing user-supplied reaches
      # `constantize`, and in development the registry can hold a class from
      # an earlier reload whose instances fail the association's type check.
      def registered_calculator_class(type)
        registry = self.class.respond_to?(:calculators) ? self.class.calculators : []
        registry.find { |klass| klass.api_type == type.to_s }&.to_s&.constantize
      end

      def self.model_name_without_spree_namespace
        to_s.tableize.tr('/', '_').sub('spree_', '')
      end

      def self.spree_calculators
        Spree.calculators
      end
    end
  end
end
