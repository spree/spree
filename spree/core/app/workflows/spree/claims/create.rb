module Spree
  module Claims
    # Opens a claim: the customer reports damaged, missing or wrong items.
    #
    # No goods come back — that is the point of a claim — so there is nothing
    # to receive and nothing to restock.
    class Create < Spree::Workflow
      hooks :validate, :after_create

      attr_reader :claim

      # @param order [Spree::Order]
      # @param items [Array<Hash>] `[{ line_item:, quantity:, description:,
      #   send_replacement:, replacement_variant:, refund_amount: }]`
      # @param claim_type [String] one of Spree::Claim.claim_types
      # @param reason [Spree::ClaimReason, nil]
      # @param memo [String, nil]
      # @param created_by [Object, nil] nil for customer self-service
      def perform(order:, items:, claim_type: 'other', reason: nil, memo: nil, created_by: nil)
        super

        step :ensure_claimable
        step :normalize_items
        run_hooks :validate

        ApplicationRecord.transaction do
          step :build_claim
        end

        run_hooks :after_create
        claim.publish_event('claim.opened')
        success(claim.reload)
      end

      private

      def ensure_claimable
        failure(order, :order_not_completed) unless order.completed?
        failure(order, :order_canceled) if order.canceled?
        failure(order, :no_items_to_claim) if items.blank?
        failure(order, :invalid_claim_type) unless Spree::Claim.claim_types.include?(claim_type.to_s)
      end

      def normalize_items
        @normalized_items = items.map do |item|
          line_item = item[:line_item]
          quantity = item[:quantity].to_i

          failure(order, :invalid_quantity) unless quantity.positive?
          failure(order, :item_not_on_order) unless line_item&.order_id == order.id
          failure(order, :invalid_quantity) if quantity > line_item.quantity.to_i

          item.merge(line_item: line_item, quantity: quantity)
        end
      end

      def build_claim
        @claim = order.claims.new(
          store: order.store,
          claim_type: claim_type,
          reason: reason,
          memo: memo,
          created_by: created_by,
          status: Spree::Claim.default_status
        )

        @normalized_items.each do |item|
          @claim.claim_line_items.build(
            line_item: item[:line_item],
            variant: item[:line_item].variant,
            quantity: item[:quantity],
            description: item[:description],
            # A caller that omits this — or passes nil for an absent param —
            # must not write NULL over the column default.
            send_replacement: ActiveModel::Type::Boolean.new.cast(item[:send_replacement]) || false,
            replacement_variant: item[:replacement_variant],
            refund_amount: item[:refund_amount] || 0
          )
        end

        failure(@claim) unless @claim.save
      end
    end
  end
end
