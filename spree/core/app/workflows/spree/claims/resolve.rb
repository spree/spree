module Spree
  module Claims
    # Makes a claim right: money back, a replacement shipment, or both.
    #
    # The resolution is an argument rather than something read off the record,
    # so the caller's intent is explicit at the call site and an admin can
    # decide at resolution time rather than at claim creation.
    class Resolve < Spree::Workflow
      hooks :validate, :before_settle, :after_resolve

      attr_reader :refunds, :fulfillments

      # @param claim [Spree::Claim] must be approved
      # @param resolution [String] one of Spree::Claim::RESOLUTIONS
      # @param refund_method [String] 'store_credit' or 'original_payment'
      # @param amount [BigDecimal, Numeric, nil] defaults to the claim total
      # @param replacement_line_item_ids [Array<Integer>, nil] which lines to
      #   replace. Nil keeps whatever was flagged when the claim was opened —
      #   the merchant usually decides what to send at resolution time, not
      #   when the customer first reported the problem.
      # @param resolver [Object, nil]
      def perform(claim:, resolution:, refund_method: 'store_credit', amount: nil,
                  replacement_line_item_ids: nil, resolver: nil)
        super

        @refunds = []
        @fulfillments = []
        step :ensure_resolvable
        step :apply_replacement_selection unless replacement_line_item_ids.nil?
        step :resolve_amount if refunding?
        run_hooks :validate

        ApplicationRecord.transaction do
          run_hooks :before_settle
          step :build_replacement_fulfillments if replacing?
          step :issue_store_credit if refunding? && internal_refund?
          step :mark_resolved
        end

        external_step :refund_at_gateway if refunding? && !internal_refund?

        step :recalculate_order
        run_hooks :after_resolve
        claim.publish_event('claim.resolved')
        success(claim.reload)
      end

      private

      def refunding?
        resolution.to_s.include?('refund')
      end

      def replacing?
        resolution.to_s.include?('replacement')
      end

      def internal_refund?
        refund_method.to_s == 'store_credit'
      end

      def ensure_resolvable
        failure(claim, :invalid_resolution) unless Spree::Claim::RESOLUTIONS.include?(resolution.to_s)
        failure(claim, :not_approved) unless claim.approved?
      end

      # A claim can never refund more than the customer paid for the affected
      # items.
      def resolve_amount
        @amount_to_refund = (amount || claim.refund_total).to_d
        ceiling = claim.claim_line_items.sum(&:paid_amount).to_d

        failure(claim, :nothing_to_refund) unless @amount_to_refund.positive?
        failure(claim, :refund_exceeds_paid) if @amount_to_refund > ceiling
      end

      # Flags exactly the chosen lines, so resolving twice with different
      # choices cannot leave stale flags behind.
      def apply_replacement_selection
        chosen = Array(replacement_line_item_ids).map(&:to_s)

        claim.claim_line_items.each do |line|
          line.update!(send_replacement: chosen.include?(line.id.to_s))
        end
        claim.claim_line_items.reload
      end

      def build_replacement_fulfillments
        units = claim.replacement_line_items.map do |line|
          claim.order.fulfillment_items.new(
            variant: line.variant_to_send,
            quantity: line.quantity,
            line_item: line.line_item,
            order: claim.order,
            status: 'on_hand'
          )
        end

        failure(claim, :nothing_to_replace) if units.empty?

        @fulfillments = Spree::Stock::Coordinator.new(claim.order, units).shipments
        if @fulfillments.flat_map(&:fulfillment_items).sum(&:quantity) != units.sum(&:quantity)
          failure(claim, :replacement_out_of_stock)
        end

        claim.order.fulfillments += @fulfillments
        claim.order.save!
        @fulfillments.each { |fulfillment| fulfillment.update!(claim.order) }
      end

      def issue_store_credit
        @refunds = [
          Spree::StoreCredit.create!(
            store: claim.store,
            customer: claim.order.customer,
            amount: @amount_to_refund,
            currency: claim.currency,
            category: Spree::StoreCreditCategory.default_refund_category,
            created_by: resolver,
            originator: claim,
            memo: "Claim #{claim.number}"
          )
        ]
      end

      def refund_at_gateway
        remaining = @amount_to_refund

        claim.order.payments.completed.each do |payment|
          break unless remaining.positive?

          creditable = [payment.credit_allowed.to_d, remaining].min
          next unless creditable.positive?

          @refunds << payment.refunds.create!(
            amount: creditable,
            reason: Spree::RefundReason.return_processing_reason,
            refunder: resolver,
            originator: claim
          )
          remaining -= creditable
        end

        failure(claim, :no_refundable_payments) if @refunds.empty?
      rescue Spree::Core::GatewayError => error
        failure(claim, error.message)
      end

      def mark_resolved
        claim.update!(status: 'resolved', resolution: resolution, resolved_at: Time.current)
      end

      def recalculate_order
        claim.order.recalculate_totals!
      end
    end
  end
end
