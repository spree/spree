module Spree
  module OrderChanges
    # Ships replacement goods for an exchange or a claim through an order
    # change, so the shipment is recorded the way every other post-placement
    # mutation is. The units are built by Spree::Fulfillments::Replacements
    # when the set is confirmed.
    module Replacements
      private

      # @param record [Spree::Exchange, Spree::Claim]
      # @param items [Array<Hash>] `[{ variant:, quantity:, line_item: }]`
      # @return [Array<Spree::Fulfillment>]
      def ship_replacements(record, items, requested_by: nil)
        actions = items.map { |item| item.merge(kind: 'add_fulfillment') }
        service = Spree.order_change_apply_service.new
        result = service.call(order: record.order, actions: actions, post_sale_record: record, requested_by: requested_by)
        failure(result.value, result.error.value) if result.failure?

        service.fulfillments
      end
    end
  end
end
