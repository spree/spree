module Spree
  module CalculatedAdjustments
    extend ActiveSupport::Concern

    included do
      has_one :calculator, class_name: 'Spree::Calculator', as: :calculable, inverse_of: :calculable, dependent: :destroy, autosave: true
      accepts_nested_attributes_for :calculator
      validates :calculator, presence: true
      delegate :compute, to: :cached_calculator

      scope :with_calculator, ->(calculator) { joins(:calculator).where(calculator: { type: calculator.to_s }) }

      def self.calculators
        spree_calculators.send model_name_without_spree_namespace
      end

      def calculator_type
        cached_calculator.class.to_s if cached_calculator
      end

      def calculator_type=(calculator_type)
        klass = calculator_type.constantize if calculator_type
        self.calculator = klass.new if klass && !calculator.instance_of?(klass)
      end

      # Returns the calculator using Rails.cache to avoid repeated database lookups.
      #
      # @return [Object, nil] The calculator object (TaxRate, PromotionAction, etc.)
      def cached_calculator
        Rails.cache.fetch("#{cache_key_with_version}/calculator") { calculator }
      rescue TypeError
        # Handle objects that can't be serialized (e.g., mock objects in tests)
        calculator
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
