module Spree
  class Order < Spree.base_class
    module Digital
      # Returns true if all order line items are digital
      #
      # @return [Boolean]
      def digital?
        if item_count.zero? || line_items.empty?
          false
        else
          line_items.includes(variant: :product).all?(&:digital?)
        end
      end

      # Returns true if any order line item is digital
      #
      # @return [Boolean]
      def some_digital?
        if item_count.zero? || line_items.empty?
          false
        else
          line_items.includes(variant: :product).any?(&:digital?)
        end
      end

      # Returns true if any order line item has digital assets
      #
      # @return [Boolean]
      def with_digital_assets?
        if item_count.zero? || line_items.empty?
          false
        else
          line_items.includes(:variant).any?(&:with_digital_assets?)
        end
      end

      # Returns all line items with digital assets
      #
      # @return [Array<Spree::LineItem>]
      def digital_line_items
        line_items.joins(:variant).with_digital_assets.distinct
      end

      # Returns all digital links for the order
      #
      # @return [Array<Spree::DigitalLink>]
      def digital_links
        digital_line_items.map(&:digital_links).flatten
      end

      # @deprecated DigitalLinks are created by
      #   Spree::FulfillmentProvider::Digital on order completion
      #   (idempotently, per quantity); removed in 6.1.
      def create_digital_links
        Spree::Deprecation.warn('Spree::Order#create_digital_links is deprecated and will be removed in Spree 6.1. Digital links are created by Spree::FulfillmentProvider::Digital on order completion.')
        provider = Spree::FulfillmentProvider::Digital.new
        digital_line_items.includes(variant: :digitals).each do |line_item|
          provider.ensure_links_for(line_item)
        end
      end

      # Fires providers that auto-fulfill on completion (digital delivery):
      # forces the fulfillment to ready and fulfills it through the machine so
      # all hooks (links, events, webhooks) run. Line items with digital
      # assets that ship through other providers (physical + download combos)
      # still get their links here, idempotently and per quantity.
      def auto_fulfill_provider_fulfillments
        handled_line_item_ids = []

        fulfillments.reload.each do |fulfillment|
          next unless fulfillment.provider.auto_fulfill?
          next if fulfillment.fulfilled? || fulfillment.canceled?

          fulfillment.update_columns(status: 'ready', updated_at: Time.current) unless fulfillment.ready?
          fulfillment.fulfill!
          handled_line_item_ids.concat(fulfillment.line_items.map(&:id))
        end

        return unless with_digital_assets?

        provider = Spree::FulfillmentProvider::Digital.new
        digital_line_items.where.not(id: handled_line_item_ids).includes(variant: :digitals).each do |line_item|
          provider.ensure_links_for(line_item)
        end
      end
    end
  end
end
