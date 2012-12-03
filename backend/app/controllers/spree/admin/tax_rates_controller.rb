module Spree
  module Admin
    class TaxRatesController < ResourceController
      before_filter :load_data

      update.after :update_after
      create.after :create_after

      private

      def load_data
        @available_zones = Zone.order(:name)
        @available_categories = TaxCategory.order(:name)
        @calculators = TaxRate.calculators.sort_by(&:name)
      end

      def update_after
        Rails.cache.delete('vat_rates')
      end

      def create_after
        Rails.cache.delete('vat_rates')
      end
    end
  end
end
