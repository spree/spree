module Spree
  module Claims
    # Makes a claim right: money back, a replacement shipment, or both.
    #
    # The resolution is an argument rather than something read off the record,
    # so the caller's intent is explicit at the call site and an admin can
    # decide at resolution time rather than at claim creation.
    class Resolve < Spree::Workflow
      # How long a resolve may hold the claim before another may take it over.
      RESERVATION_TTL = 10.minutes

      include Spree::Refunds::OrderPayments
      include Spree::Refunds::TaxCredit
      include Spree::Fulfillments::Replacements

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

        # Only one request may resolve a claim. The claim is reserved under a
        # short row lock before anything is written, so a request that loses
        # the race changes nothing, and the tax provider is asked outside any
        # transaction.
        step :reserve_claim, on_flow_failure: :release_claim
        step :settle_tax

        ApplicationRecord.transaction do
          step :confirm_reservation
          step :save_replacement_selection
          run_hooks :before_settle
          step :build_replacement_fulfillments if replacing?
          step :issue_store_credit if refunding? && internal_refund?
          step :mark_resolved
        end

        external_step :refund_at_gateway if refunding? && !internal_refund?
        external_step :refund_tax if refunding?

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
        if refunding? && !Spree::RefundMethods.valid?(refund_method)
          # :base, not :refund_method — it is a workflow argument, not an
          # attribute, and ActiveModel raises when an error names one that
          # does not exist on the record.
          claim.errors.add(:base, :invalid_refund_method,
                           message: I18n.t('spree.errors.messages.invalid_refund_method'))
          failure(claim)
        end
        # Read fresh: a caller may hold a copy loaded before another request
        # resolved the claim.
        failure(claim, :not_approved) unless claim.reload.approved?
      end

      # Marks the claim as being resolved by writing the resolution while it
      # is still approved, under the claim's row lock, so a second request
      # sees the mark and stops. A mark older than RESERVATION_TTL is left by
      # a request that died, and may be taken over. A separate copy is locked
      # so the replacement choice held on `claim`'s lines survives.
      def reserve_claim
        ApplicationRecord.transaction do
          locked = Spree::Claim.lock.find(claim.id)
          failure(claim, :not_approved) unless locked.approved?
          failure(claim, :resolution_in_progress) if locked.resolution.present? && locked.updated_at > RESERVATION_TTL.ago

          locked.update_columns(resolution: resolution.to_s, updated_at: Time.current)
          # Read back as stored, so #release_claim can find its own mark again.
          @reserved_at = locked.reload.updated_at
          # What #settle_tax is about to rewrite, for #restore_tax_rows.
          @tax_rows_before = claim_tax_rows.map { |row| row.attributes.slice(*Spree::TaxLine.column_names).except('id') }
        end
      end

      # Still approved under the lock, so even a request whose mark was taken
      # over cannot pay out once another has resolved the claim.
      def confirm_reservation
        failure(claim, :not_approved) unless Spree::Claim.lock.find(claim.id).approved?
      end

      # A resolve that failed before marking the claim resolved hands it back
      # — only its own mark, never one a later request took over.
      def release_claim
        restore_tax_rows
      ensure
        held = Spree::Claim.where(id: claim.id, status: 'approved', resolution: resolution.to_s, updated_at: @reserved_at)
        held.update_all(resolution: nil, updated_at: Time.current)
      end

      # The credit rows are rewritten outside the transaction, so a resolve
      # that fails during or after #settle_tax puts back the rows it found on
      # a claim it still holds, and drops them from one canceled or denied
      # meanwhile. A claim another request took over or resolved keeps the
      # rows as they stand.
      def restore_tax_rows
        ApplicationRecord.transaction do
          current = Spree::Claim.lock.find(claim.id)

          if current.approved? && current.resolution == resolution.to_s && current.updated_at == @reserved_at
            claim_tax_rows.delete_all
            Spree::TaxLine.insert_all(@tax_rows_before) if @tax_rows_before.present?
          elsif current.status.in?(%w[canceled denied])
            current.clear_tax!
          end
        end
      end

      def claim_tax_rows
        Spree::TaxLine.post_sale.where(Spree::TaxLine.adjustable_key_for(Spree::ClaimLineItem) => claim.claim_line_items.select(:id))
      end

      # Rewrites the credit rows for the money actually going back — each line's
      # share of it follows the refund agreed for that line — or clears them
      # when the claim is put right with a replacement alone.
      def settle_tax
        lines = claim.claim_line_items.to_a
        amounts = if refunding?
                    weights = lines.index_with(&:refund_amount)
                    weights = lines.index_with(&:paid_amount) if weights.values.sum.zero?
                    allocate_refund(@amount_to_refund, weights, claim.currency)
                  else
                    lines.index_with { 0.to_d }
                  end

        with_tax_provider(claim) { claim.settle_tax!(amounts: amounts) }
        @tax_amount = claim.credited_tax_total
      end

      def refund_tax
        file_tax_credit(claim, claim.claim_line_items.to_a, @amount_to_refund)
      end

      # A claim can never refund more than the customer paid for the affected
      # items, tax included.
      def resolve_amount
        @amount_to_refund = (amount || claim.refund_total).to_d
        ceiling = claim.claim_line_items.sum(&:paid_amount).to_d

        failure(claim, :nothing_to_refund) unless @amount_to_refund.positive?
        failure(claim, :refund_exceeds_paid) if @amount_to_refund > ceiling
      end

      # Flags exactly the chosen lines, so resolving twice with different
      # choices cannot leave stale flags behind. Held in memory for the
      # validate hooks, and saved once the claim is locked.
      def apply_replacement_selection
        chosen = Array(replacement_line_item_ids).map(&:to_s)

        claim.claim_line_items.each do |line|
          line.send_replacement = chosen.include?(line.id.to_s)
        end
      end

      def save_replacement_selection
        claim.claim_line_items.each { |line| line.save! if line.changed? }
      end

      def build_replacement_fulfillments
        items = claim.replacement_line_items.map do |line|
          { variant: line.variant_to_send, quantity: line.quantity, line_item: line.line_item }
        end

        failure(claim, :nothing_to_replace) if items.empty?

        @fulfillments = build_replacements(claim, items)
      end

      def issue_store_credit
        @refunds = issue_refund_store_credit(
          order: claim.order,
          amount: @amount_to_refund,
          record: claim,
          memo: "Claim #{claim.number}",
          refunder: resolver
        )
      end

      def refund_at_gateway
        @refunds = refund_order_payments(
          order: claim.order,
          amount: @amount_to_refund,
          record: claim,
          refunder: resolver,
          tax_amount: @tax_amount
        )

        failure(claim, :no_refundable_payments) if @refunds.empty?
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
