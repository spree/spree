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

        step :require_something_to_apply_to
        run_hooks :validate

        ApplicationRecord.transaction do
          step :mark_live
          run_hooks :after_activate
        end

        success(price_list)
      end

      private

      # A list with no rules, no catalog and no products applies to everyone
      # and prices nothing. A draft may sit in that state while it is built;
      # making it live is refused so that emptiness reads as the mistake it
      # is rather than silently going nowhere.
      def require_something_to_apply_to
        return if price_list.catalog_id.present?
        return if price_list.price_rules.any?
        return if price_list.prices.exists?

        price_list.errors.add(:base, :nothing_to_apply_to)
        failure(price_list)
      end

      def scheduled?
        price_list.starts_at.present? && price_list.starts_at.future?
      end

      def mark_live
        failure(price_list) unless price_list.update(status: scheduled? ? 'scheduled' : 'active')
      end
    end
  end
end
