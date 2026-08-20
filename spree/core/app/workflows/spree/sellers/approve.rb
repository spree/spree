module Spree
  module Sellers
    # Lets a seller trade. Also the way back for one that was suspended or
    # turned down, which is why the guard admits more than the linear path.
    class Approve < Spree::Workflow
      hooks :validate, :after_approve

      # Requirement statuses that were outstanding at approval — empty
      # unless the operator overrode them.
      # @return [Array<Spree::SellerRequirementStatus>]
      attr_reader :unmet_requirements

      # @param seller [Spree::Seller]
      # @param approver [Object, nil] the staff member approving
      # @param override_requirements [Boolean] admit the seller even though
      #   the marketplace's checklist is not finished — the operator's
      #   deliberate exception, recorded on the event
      def perform(seller:, approver: nil, override_requirements: false)
        super

        step :ensure_approvable
        step :ensure_requirements_met
        run_hooks :validate

        ApplicationRecord.transaction do
          step :mark_approved
        end

        run_hooks :after_approve
        seller.publish_event('seller.approved', nil,
                             requirements_overridden: override_requirements,
                             unmet_requirements: unmet_requirement_names)
        success(seller.reload)
      end

      private

      def ensure_approvable
        failure(seller, :already_approved) if seller.approved?

        return if seller.onboarding? || seller.ready_for_review? ||
                  seller.suspended? || seller.rejected?

        failure(seller, :not_approvable)
      end

      # The checklist gates admission, and the operator can step over it —
      # they know things about a seller the marketplace never asked for. What
      # they cannot do is step over it without saying so, which is what makes
      # the override worth recording on the event.
      #
      # A suspended seller being reinstated is not re-measured: they were
      # admitted once, and lifting a suspension undoes that decision rather
      # than making it again.
      #
      # A rejected seller is the opposite case, even though both are
      # "reinstatements" in the loose sense: Sellers::Reject refuses an
      # approved seller outright, so every rejected seller is an applicant
      # who was turned away before admission. Approving one is the original
      # decision, and skipping the checklist for it would admit a seller with
      # unmet requirements while the event recorded no override.
      def ensure_requirements_met
        @unmet_requirements = []
        return if seller.suspended?

        requirements = Spree::Sellers::Requirements.new(seller)
        @unmet_requirements = requirements.blocking
        return if unmet_requirements.empty?
        return if override_requirements

        requirements.record_blocking(errors)
        failure(seller, errors)
      end

      # @return [Array<String>]
      def unmet_requirement_names
        Array(unmet_requirements).map(&:name)
      end

      # Lifting a suspension clears the holiday with it: a seller coming back
      # is coming back to sell, and leaving them invisible would look like the
      # approval had not worked.
      def mark_approved
        seller.update!(status: 'approved', holiday_mode_until: nil)
      end
    end
  end
end
