module Spree
  module Exchanges
    # Records what came back. Same partial-receipt shape as returns: the
    # warehouse enters actual quantities and flags anything unsellable.
    class Receive < Spree::Workflow
      include Spree::PostSale::Receipt

      hooks :validate, :before_restock, :after_receive

      # @param exchange [Spree::Exchange]
      # @param items [Array<Hash>, nil] `[{ exchange_line_item:, quantity:, resellable: }]`
      # @param received_by [Object, nil]
      def perform(exchange:, items: nil, received_by: nil)
        super
        receive
      end

      private

      def post_sale_record = exchange

      def restock_variant(line)
        line.original_variant
      end
    end
  end
end
