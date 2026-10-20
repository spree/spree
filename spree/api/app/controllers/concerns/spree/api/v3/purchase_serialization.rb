module Spree
  module Api
    module V3
      # Which serializer describes what a checkout produced.
      #
      # A checkout answers with one record: the order it placed, or — when the
      # basket reached several sellers — the group holding one order per
      # seller. Which of the two it is follows the record, never the endpoint,
      # so every surface that resolves a checkout hands back the whole purchase
      # rather than one seller's share of it.
      module PurchaseSerialization
        extend ActiveSupport::Concern

        protected

        # @param record [Spree::Order, Spree::OrderGroup, Spree::Cart]
        # @return [Class] the serializer that describes it
        def purchase_serializer_for(record)
          return Spree.api.order_group_serializer if record.is_a?(Spree::OrderGroup)

          Spree.api.order_serializer
        end
      end
    end
  end
end
