module Spree
  module Sellers
    # The seller says they are ready. One of the two places the onboarding
    # checklist is enforced (docs/plans/6.0-seller-onboarding-requirements.md);
    # the other is Spree::Sellers::Approve.
    #
    # A marketplace that trusts its checklist can let this approve outright —
    # the `auto_approve_sellers` store preference — which is what turns the
    # checklist from a queue for the operator into the admission decision.
    class SubmitForReview < Spree::Workflow
      hooks :validate, :after_submit

      # Requirement statuses that stood in the way, for hook handlers and
      # for the caller rendering the refusal.
      # @return [Array<Spree::SellerRequirementStatus>]
      attr_reader :blocking_requirements

      # @param seller [Spree::Seller]
      # @param submitted_by [Object, nil] the seller's own staff member
      def perform(seller:, submitted_by: nil)
        super

        step :ensure_submittable
        step :ensure_requirements_met
        run_hooks :validate

        ApplicationRecord.transaction do
          step :mark_ready_for_review
        end

        run_hooks :after_submit
        seller.publish_event('seller.submitted_for_review')

        # Approval is its own workflow with its own mail and hooks, so
        # automatic admission runs it rather than reproducing it — and does so
        # outside this workflow's transaction, since approving is not part of
        # submitting and must not roll it back.
        return step :auto_approve if auto_approve?

        success(seller.reload)
      end

      private

      def ensure_submittable
        failure(seller, :already_submitted) if seller.ready_for_review?
        failure(seller, :already_approved) if seller.approved?

        return if seller.onboarding?

        failure(seller, :not_submittable)
      end

      def ensure_requirements_met
        requirements = Spree::Sellers::Requirements.new(seller)
        @blocking_requirements = requirements.blocking
        return if blocking_requirements.empty?

        requirements.record_blocking(errors)
        failure(seller, errors)
      end

      def mark_ready_for_review
        seller.update!(status: 'ready_for_review')
      end

      def auto_approve?
        seller.store&.preferred_auto_approve_sellers.present?
      end

      def auto_approve
        Spree::Sellers::Approve.call(seller: seller.reload, approver: nil)
      end
    end
  end
end
