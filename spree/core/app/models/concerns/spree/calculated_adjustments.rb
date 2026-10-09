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
      # payload. Preferences are checked against the calculator's schema and
      # written through its typed writers.
      def assign_calculator_attributes(attrs)
        return if attrs.nil?

        attrs = attrs.to_h.with_indifferent_access
        self.calculator_type = attrs[:type] if attrs[:type].present?

        return if calculator.nil? || attrs[:preferences].blank?

        begin
          calculator.assign_preferences(attrs[:preferences])
        rescue Spree::Preferences::InvalidPreferences => e
          raise e.within('/calculator')
        end
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
