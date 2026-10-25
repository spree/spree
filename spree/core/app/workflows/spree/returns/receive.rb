module Spree
  module Returns
    # Records what the warehouse actually received (see Spree::PostSale::Receipt).
    class Receive < Spree::Workflow
      include Spree::PostSale::Receipt

      hooks :validate, :before_restock, :after_receive

      # @param return_record [Spree::Return]
      # @param items [Array<Hash>, nil] `[{ return_line_item:, quantity:,
      #   resellable: }]`; nil receives everything as requested and resellable
      # @param received_by [Object, nil]
      def perform(return_record:, items: nil, received_by: nil)
        super
        receive
      end

      private

      def post_sale_record = return_record
    end
  end
end
