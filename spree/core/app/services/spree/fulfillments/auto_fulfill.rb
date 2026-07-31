module Spree
  module Fulfillments
    # Fires providers that auto-fulfill on completion (digital delivery):
    # forces each auto-fulfill fulfillment to ready and fulfills it through
    # the machine so all hooks (links, events, webhooks) run. Line items
    # with digital assets that ship through other providers (physical +
    # download combos) still get their links, idempotently and per
    # quantity. Runs during finalize, before the confirmation email
    # subscriber reads the links.
    class AutoFulfill
      prepend Spree::ServiceModule::Base

      def call(order:)
        handled_line_item_ids = []

        order.fulfillments.reload.each do |fulfillment|
          next unless fulfillment.provider.auto_fulfill?
          next if fulfillment.fulfilled? || fulfillment.canceled?

          fulfillment.update_columns(status: 'ready', updated_at: Time.current) unless fulfillment.ready?
          fulfillment.fulfill!
          handled_line_item_ids.concat(fulfillment.line_items.map(&:id))
        end

        return success(order) unless order.with_digital_assets?

        provider = Spree::FulfillmentProvider::Digital.new
        order.digital_line_items.where.not(id: handled_line_item_ids).includes(variant: :digitals).each do |line_item|
          provider.ensure_links_for(line_item)
        end

        success(order)
      end
    end
  end
end
