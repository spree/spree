module Spree
  module Carts
    # One entry of an upsert batch after its variant has been looked up:
    # what Spree::Carts::UpsertItems validates and applies.
    class ResolvedItem
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :quantity, :integer, default: 1
      # price is tri-state: absent (price_provided false) leaves pricing to
      # the resolver, an amount negotiates the line (price_source 'manual'),
      # an explicit nil reverts a negotiated line to catalog pricing.
      attribute :price_provided, :boolean, default: false
      attr_accessor :variant, :metadata, :price

      def metadata
        @metadata ||= {}
      end

      # Zero (or less) is how a batch says "this line is gone", which is what
      # lets one request carry edits and removals together.
      def remove?
        quantity <= 0
      end

      # @return [Boolean] the entry sets a negotiated unit price
      def manual_price?
        price_provided && !price.nil?
      end

      # @return [Boolean] the entry reverts a negotiated line to catalog pricing
      def revert_price?
        price_provided && price.nil?
      end
    end
  end
end
