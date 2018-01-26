module Spree
  module Admin
    class TaxRatesController < ResourceController
      before_action :set_calculator_type, only: [:create, :update]
      before_action :load_data

      private

      def set_calculator_type
        klass = params[@resource.object_name.to_sym][:calculator_type]
        @object.build_calculator(type: klass) if @object.calculator.class.to_s != klass
      end

      def load_data
        @available_zones = Zone.order(:name)
        @available_categories = TaxCategory.order(:name)
        @calculators = Spree::Calculator.calculators_for(:tax_rates)
      end
    end
  end
end
