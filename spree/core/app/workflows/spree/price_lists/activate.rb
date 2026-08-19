module Spree
  module PriceLists
    # Puts a price list into effect. A list whose start date is still in the
    # future is scheduled instead of activated, so activating is always the
    # single answer to "make this list live" regardless of its dates.
    class Activate < Spree::Workflow
      hooks :validate, :after_activate

      # @param price_list [Spree::PriceList]
      # @return [Spree::ServiceModule::Result] value is the price list
      def perform(price_list:)
        super

        run_hooks :validate

        ApplicationRecord.transaction do
          step :mark_live
          run_hooks :after_activate
        end

        success(price_list)
      end

      private

      def scheduled?
        price_list.starts_at.present? && price_list.starts_at.future?
      end

      def mark_live
        failure(price_list) unless price_list.update(status: scheduled? ? 'scheduled' : 'active')
      end
    end
  end
end
