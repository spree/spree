module Spree
  module Carts
    # One entry of an upsert batch after its variant has been looked up:
    # what Spree::Carts::UpsertItems validates and applies.
    class ResolvedItem
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :quantity, :integer, default: 1
      attr_accessor :variant, :metadata

      def metadata
        @metadata ||= {}
      end

      # Zero (or less) is how a batch says "this line is gone", which is what
      # lets one request carry edits and removals together.
      def remove?
        quantity <= 0
      end
    end
  end
end
