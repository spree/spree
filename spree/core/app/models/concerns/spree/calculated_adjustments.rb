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

        registry = self.class.respond_to?(:calculators) ? self.class.calculators : []
        klass = registry.find { |k| k.api_type == calculator_type.to_s }
        self.calculator = klass.new if klass && !calculator.instance_of?(klass)
      end

      # API v3 writer for the `calculator: { type:, preferences: {} }`
      # payload. A type the registry does not list is an error on
      # `calculator`; preferences are checked against the calculator's schema
      # and written through its typed writers.
      #
      # @param attrs [Hash, ActionController::Parameters, nil]
      # @param pointer [String] where the calculator sits in the request
      # @return [void]
      def assign_calculator_attributes(attrs, pointer: '/calculator')
        return if attrs.nil?

        attrs = attrs.to_h.with_indifferent_access
        type = attrs[:type].to_s
        if type.present? && calculator&.class&.api_type != type
          registry = self.class.respond_to?(:calculators) ? self.class.calculators : []
          registered = registry.find { |klass| klass.api_type == type }
          return errors.add(:calculator, :invalid) unless registered

          # Resolved from the registry entry's own name, never the request's:
          # in development the registry can hold a class from an earlier
          # reload, whose instances fail the association's type check.
          self.calculator = registered.to_s.constantize.new
        end
        return if attrs[:preferences].blank?

        # Preferences sent without a type land on the default calculator
        # rather than on nothing, where the model builds one.
        ensure_calculator if respond_to?(:ensure_calculator, true)
        calculator&.assign_preferences(attrs[:preferences], pointer: "#{pointer}/preferences")
      end

      private

      def self.model_name_without_spree_namespace
        to_s.tableize.tr('/', '_').sub('spree_', '')
      end

      def self.spree_calculators
        Spree.calculators
      end
    end
  end
end
