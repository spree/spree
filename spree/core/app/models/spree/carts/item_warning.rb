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

      def to_h
        { item_index: item_index, variant_id: variant&.prefixed_id, code: code, message: message }
      end
    end
  end
end
