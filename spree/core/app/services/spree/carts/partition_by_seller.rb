module Spree
  module Carts
    # Decides how a purchase divides into orders, and refreshes the line items
    # whose answer has gone stale.
    #
    # The partition key is the line item's own +seller_id+, denormalised from
    # the variant at add-to-cart. It has to be revalidated before the split
    # because ownership can change while items sit in a cart — a seller takes
    # over a listing, an operator brings one in-house — and partitioning on a
    # stale snapshot would file the sale under a seller who no longer sells it.
    #
    # Items with no seller are the operator's own goods, and they form a
    # partition of their own rather than being folded into anyone else's. That
    # is what makes a mixed basket — some first-party stock, some from two
    # sellers — divide into three orders, one of which is a perfectly ordinary
    # first-party order carrying no seller and no commission.
    class PartitionBySeller
      prepend Spree::ServiceModule::Base

      # @param purchase [Spree::Cart, Spree::Order] whatever owns the line items
      #   being divided; the completion passes the paid draft order
      # @return [Spree::ServiceModule::Result] value is an Array of
      #   Spree::Carts::SellerPartition, first party first and then by seller id,
      #   so a checkout divides the same way twice running
      def call(purchase:)
        line_items = purchase.line_items.includes(variant: :product).to_a
        refresh_stale_sellers(line_items)

        partitions = line_items.group_by(&:seller_id).map do |seller_id, items|
          SellerPartition.new(seller_id: seller_id, line_items: items)
        end

        success(partitions.sort_by { |partition| [partition.seller_id.nil? ? 0 : 1, partition.seller_id.to_i] })
      end

      private

      # Re-reads each line's seller from the variant it points at. Writes only
      # the rows that actually moved, and through update_columns: this runs
      # inside completion, and touching a line item would re-enter recalculation
      # for a change that alters no money. The in-memory rows are updated with
      # it, so the grouping above sees the refreshed answer without re-reading.
      def refresh_stale_sellers(line_items)
        line_items.each do |line_item|
          current = line_item.variant&.resolved_seller_id
          next if current == line_item.seller_id

          line_item.update_columns(seller_id: current, updated_at: Time.current)
        end
      end
    end

    # One order's worth of a divided purchase.
    class SellerPartition
      include ActiveModel::Model
      include ActiveModel::Attributes

      # Nil on the operator's own goods, which form a partition like any other.
      attribute :seller_id, :integer
      attr_accessor :line_items

      # What this partition's items are worth before delivery, taxes and
      # order-level money — the weight order-level rows prorate by.
      #
      # @return [BigDecimal]
      def item_total
        line_items.sum(&:amount)
      end
    end
  end
end
