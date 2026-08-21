# frozen_string_literal: true

module Spree
  module Marketplace
    # What a marketplace wants to know about one checkout's group of orders.
    #
    # {Spree::OrderGroup} is deliberately domain-neutral — "N orders placed
    # together as one customer transaction" — because the same container serves
    # split-by-location, split-by-availability and B2B split-by-company-location,
    # none of which involve a seller
    # (docs/plans/6.0-multi-vendor-marketplace.md, Decision 8). So the seller is
    # asked about here rather than there, and the primitive keeps meaning the
    # same thing for its other consumers.
    module OrderGroup
      extend ActiveSupport::Concern

      # @return [ActiveRecord::Relation<Spree::Seller>] the sellers this
      #   checkout reached; the operator's own goods contribute none
      def sellers
        store.sellers.where(id: orders.filter_map(&:seller_id).uniq)
      end

      # @return [Integer]
      def seller_count
        orders.filter_map(&:seller_id).uniq.size
      end

      # @return [Boolean] whether any child order carries no seller — the
      #   operator's own goods, bought alongside sellers' in one checkout
      def includes_first_party?
        orders.any? { |order| order.seller_id.nil? }
      end
    end
  end
end
