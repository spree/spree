module Spree
  module Orders
    # Files a sale under the seller who made it, dividing the order into one
    # per seller when it holds several sellers' goods.
    #
    # Both ways an order is placed run this — a checkout before it places its
    # children, an admin draft inside its own completion — because commission
    # is charged from the line item's seller while the ledger credits the
    # order's, and an order that skipped this would be charged for and credited
    # to nobody (docs/plans/6.0-multi-vendor-marketplace.md).
    #
    # Expects a draft order whose money is already settled: the payment is
    # taken once against the whole basket and apportioned here.
    class AttributeToSeller
      prepend Spree::ServiceModule::Base

      # @param order [Spree::Order] a draft, with its money settled
      # @param cart [Spree::Cart, nil] nil for an order raised from the admin,
      #   which never had one
      # @return [Spree::ServiceModule::Result] value is the Spree::OrderGroup
      #   the order divided into, or nil when it stayed whole
      def call(order:, cart: nil)
        partitions = Spree::Carts::PartitionBySeller.call(purchase: order).value

        return success(nil) if partitions.empty?
        return stamp(order, partitions.first.seller_id) if partitions.one?

        split_order(order, partitions, cart)
      end

      private

      # Nothing to divide, but the sale still belongs to whoever made it: a
      # basket entirely from one seller is that seller's order, and the column
      # is what their own order list reads.
      def stamp(order, seller_id)
        order.update_columns(seller_id: seller_id, updated_at: Time.current) if order.seller_id != seller_id

        success(nil)
      end

      def split_order(order, partitions, cart)
        result = Spree::Carts::SplitBySeller.call(order: order, partitions: partitions, cart: cart)
        return result if result.failure?

        Spree::OrderGroups::AllocatePayments.call(group: result.value)
      end
    end
  end
end
