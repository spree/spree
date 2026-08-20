# frozen_string_literal: true

module Spree
  module Sellers
    # Evaluates a seller against their marketplace's onboarding requirements
    # (docs/plans/6.0-seller-onboarding-requirements.md).
    #
    # The single place that answers "what does this seller still have to do",
    # so the seller's own panel, the operator's view of them and the two
    # workflows that gate approval all say the same thing. Every answer is
    # computed on read: a stored copy would disagree with the data the moment
    # a product, an address or a document changed.
    #
    #   requirements = Spree::Sellers::Requirements.new(seller)
    #   requirements.met?      # => false
    #   requirements.blocking  # => [#<SellerRequirementStatus name: "Returns address">]
    class Requirements
      # @param seller [Spree::Seller]
      # @param preloaded [Boolean] read the store's checklist off its loaded
      #   association rather than querying. Only a caller that eager-loaded it
      #   should say so — a page of sellers shares one store, so its rows load
      #   once for all of them — because trusting whatever happens to be
      #   cached would let a gate measure against a stale checklist.
      def initialize(seller, preloaded: false)
        @seller = seller
        @preloaded = preloaded
      end

      # The checklist, in the operator's order. Requirements a kind says do
      # not apply to this seller are absent rather than shown as unmet.
      #
      # @return [Array<Spree::SellerRequirementStatus>]
      def statuses
        @statuses ||= applicable_requirements.map { |requirement| build_status(requirement) }
      end

      # What stands between the seller and approval: required, and not met.
      #
      # @return [Array<Spree::SellerRequirementStatus>]
      def blocking
        statuses.select(&:blocking?)
      end

      # @return [Boolean] whether every required requirement is met
      def met?
        blocking.empty?
      end

      # Records what is outstanding on an errors object, naming each one: the
      # seller has to act on the refusal, and a bare "not ready" leaves them
      # guessing which of eight things it meant.
      #
      # @param errors [ActiveModel::Errors]
      # @return [Array<Spree::SellerRequirementStatus>] what was recorded
      def record_blocking(errors)
        blocking.each do |requirement|
          errors.add(:requirements, :incomplete,
                     message: Spree.t('seller_requirements.incomplete', name: requirement.name,
                                                                       default: "#{requirement.name} is not complete"))
        end
      end

      # Progress over the whole checklist, optional requirements included —
      # a seller reads it as how far through they are, not as how close to
      # approval, and hiding the optional ones would make it jump.
      #
      # @return [Hash{Symbol => Integer}]
      def progress
        self.class.progress_of(statuses)
      end

      # The one definition of "how far along", so the evaluator and the
      # seller's own readers cannot drift apart. A checklist that asks for
      # nothing reads as finished.
      #
      # @param statuses [Array<Spree::SellerRequirementStatus>]
      # @return [Hash{Symbol => Integer}]
      def self.progress_of(statuses)
        total = statuses.size
        done = statuses.count(&:complete?)

        {
          done: done,
          total: total,
          percentage: total.zero? ? 100 : (done / total.to_f * 100).round
        }
      end

      private

      attr_reader :seller

      # Requirements are configuration on the store, so an unsaved or
      # store-less seller has nothing to be measured against.
      #
      # `seller_requirements` carries its own order. Submissions are read
      # through the seller (see SellerRequirement#latest_submission), so
      # nothing here loads other sellers' rows.
      def applicable_requirements
        return [] if seller.nil? || seller.store.nil?

        rows = @preloaded ? seller.store.seller_requirements.to_a : seller.store.seller_requirements.active.to_a

        rows.select { |requirement| requirement.active? && requirement.applicable?(seller) }
      end

      def build_status(requirement)
        Spree::SellerRequirementStatus.new(
          id: requirement.prefixed_id,
          kind: requirement.class.api_type,
          name: requirement.display_name,
          description: requirement.display_description,
          required: requirement.required,
          position: requirement.position,
          status: requirement.status_for(seller),
          action_url: requirement.action_url(seller),
          submission: requirement.latest_submission(seller)
        )
      end
    end
  end
end
