module Spree
  module Purchase
    # Digitality predicates over line items, shared by Spree::Cart and
    # Spree::Order (fulfillment-side digital delivery stays order-only in
    # Spree::Order::Digital).
    module DigitalItems
      # @return [Boolean] true when every line item is digital
      def digital?
        if total_quantity.zero? || line_items.empty?
          false
        else
          line_items_with_variants(variant: :product).all?(&:digital?)
        end
      end

      # @return [Boolean] true when any line item is digital
      def some_digital?
        if total_quantity.zero? || line_items.empty?
          false
        else
          line_items_with_variants(variant: :product).any?(&:digital?)
        end
      end

      # @return [Boolean] true when any line item has digital assets
      def with_digital_assets?
        if total_quantity.zero? || line_items.empty?
          false
        else
          line_items_with_variants(variant: :digital_assets).any?(&:with_digital_assets?)
        end
      end

      # @return [ActiveRecord::Relation<Spree::LineItem>]
      def digital_line_items
        line_items.joins(:variant).with_digital_assets.distinct
      end

      # One query rather than one per line item — this is read for every
      # digital order's email. `reorder(nil)` drops the line-item default order:
      # PostgreSQL rejects SELECT DISTINCT ordered by a column that is not in
      # the select list, and ordering a subquery buys nothing anyway.
      #
      # @return [ActiveRecord::Relation<Spree::DigitalLink>]
      def digital_links
        Spree::DigitalLink.where(line_item_id: digital_line_items.reorder(nil).select(:id))
      end

      # Whether the customer must choose a delivery option in checkout —
      # shipping and both pickup kinds are chosen; digital fulfillments are
      # created by their provider without a selection. Delivery itself
      # happens for all of them.
      #
      # @return [Boolean]
      def delivery_step_required?
        line_items.any? && !digital?
      end

      private

      # Lines already in memory get the associations preloaded onto them —
      # onto every line of their preload context when they sit in a list, so
      # the list batches them instead of querying once per purchase.
      def line_items_with_variants(associations)
        return line_items.includes(associations) unless read_association_in_memory?(:line_items)

        loaded = line_items.to_a
        records = loaded.first&.lazy_preload_context&.records || loaded
        ActiveRecord::Associations::Preloader.new(records: records, associations: associations).call
        loaded
      end
    end
  end
end
