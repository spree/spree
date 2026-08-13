module Spree
  module Carts
    # An item a batch upsert did not apply — vetoed by a :validate handler or
    # unavailable in the cart's currency. The batch still succeeds, so this is
    # how the caller learns which lines were dropped and why.
    class ItemWarning
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :item_index, :integer
      attribute :code, :string
      attribute :message, :string
      attr_accessor :variant

      # Same shape as the out-of-stock warnings the cart already carries, so
      # a client reads one warnings array rather than two vocabularies.
      # item_index is the batch position, present only for batch upserts.
      def to_h
        {
          code: code,
          message: message,
          variant_id: variant&.prefixed_id,
          item_index: item_index
        }.compact
      end
    end
  end
end
