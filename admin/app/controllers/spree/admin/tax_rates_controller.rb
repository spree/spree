module Spree
  module Admin
    class TaxRatesController < ResourceController
      before_action :load_data
      before_action :set_defaults, only: :new

      private

      def set_defaults
        @object.calculator_type = 'Spree::Calculator::DefaultTax'
      end

      def load_data
        @available_zones = Spree::Zone.order(:name)
        @available_categories = Spree::TaxCategory.order(:name)
        @calculators = Spree::TaxRate.calculators.sort_by(&:name)
      end
    end
  end
end
