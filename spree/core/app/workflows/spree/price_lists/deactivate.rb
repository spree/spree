module Spree
  module PriceLists
    # Takes a price list out of effect. Its prices stop applying immediately;
    # nothing about them is discarded, so it can be activated again later.
    class Deactivate < Spree::Workflow
      hooks :validate, :after_deactivate

      # @param price_list [Spree::PriceList]
      # @return [Spree::ServiceModule::Result] value is the price list
      def perform(price_list:)
        super

        run_hooks :validate

        ApplicationRecord.transaction do
          step :mark_inactive
          run_hooks :after_deactivate
        end

        success(price_list)
      end

      private

      def mark_inactive
        failure(price_list) unless price_list.update(status: 'inactive')
      end
    end
  end
end
