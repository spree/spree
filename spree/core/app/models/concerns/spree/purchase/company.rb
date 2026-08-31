module Spree
  module Purchase
    # Which company node a sale is for, shared by Spree::Cart and
    # Spree::Order. The purchase points at any node in the tree — buying *for*
    # a division is pointing at it — and tax reads through the node's legal
    # entity, never the node itself
    # (docs/plans/6.0-b2b-companies-and-catalogs.md).
    module Company
      extend ActiveSupport::Concern

      included do
        belongs_to :company, class_name: 'Spree::Company', optional: true

        # Guarded on the model rather than in the controller so every path is
        # covered — the admin write, the storefront one, and the console.
        # Companies are store-scoped, so a node from another store would tax
        # this sale against a business the merchant does not trade as.
        validate :company_belongs_to_store, if: :company_id_changing?
        # The storefront's write path is the cart; an order's company arrives
        # from completion (already validated on the cart) or from staff, whose
        # authority is the admin credential rather than a membership. A guest
        # cart has no standing at all, so naming a company on one is refused
        # outright — company ids are not secrets, and a token-authorized cart
        # must not be able to claim another business's tax exemptions and
        # catalog prices.
        validate :customer_has_standing_over_company,
                 if: -> { is_a?(Spree::Cart) && company_id_changing? }
      end

      # @return [Boolean] whether this sale is for a business customer
      def b2b?
        resolved_company.present?
      end

      # The node this sale is for. An explicit choice wins; otherwise a buyer
      # whose standing in this store resolves to exactly one membership is
      # unambiguous and resolves to that membership's node.
      #
      # A buyer with several memberships resolves to nothing until the cart
      # says which node it is for — refusing to guess, because guessing would
      # invoice one business for another's purchase.
      #
      # @return [Spree::Company, nil]
      def resolved_company
        # A placed order answers from what it was stamped with, never by
        # resolving again — otherwise adding a buyer to a company months later
        # would reach back and exempt an order that legitimately charged tax.
        return company if is_a?(Spree::Order) && completed?
        if company_id.present?
          # A dangling id keeps today's behavior; the association answers nil.
          return company if company.nil?

          # An in-flight sale re-asks the policy: a company deactivated after
          # being named must not keep exempting the sale through its
          # certificates. Deliberately nil rather than the sole-standing
          # fallback — the buyer named a node, and resolving a different one
          # would invoice one business for another's purchase.
          return Spree.company_activation_policy.active?(company) ? company : nil
        end

        sole_standing_company
      end

      # The tax anchor for this sale: the resolved node's nearest
      # self-or-ancestor legal entity. Registrations and exemption
      # certificates are always read through it — a division holds none, and
      # reading the node's own would silently lose the exemption.
      #
      # @return [Spree::Company, nil]
      def company_legal_entity
        resolved_company&.legal_entity
      end

      # Whether an +approval_required+ channel must refuse completion.
      # {#resolved_company} is the policy-filtered answer — an inactive
      # sole standing or named node already resolves to nothing — so the
      # question reduces to the posture plus an empty resolution. The
      # staff exemption lives with the checkout requirement that consumes
      # this (docs/plans/6.0-b2b-company-self-registration.md).
      #
      # @return [Boolean]
      def company_activation_missing?
        return false if channel.blank? || !channel.storefront_approval_required?

        resolved_company.nil?
      end

      private

      def company_id_changing?
        new_record? ? company_id.present? : will_save_change_to_company_id?
      end

      def company_belongs_to_store
        return if company.nil? || store_id.nil?
        return if company.store_id == store_id

        errors.add(:company, :invalid)
      end

      def customer_has_standing_over_company
        return if company.nil?
        return errors.add(:company, :invalid) unless customer&.standing_for?(company)
        # Distinct from :invalid so a storefront can tell "not yours" from
        # "not yet activated" — the latter is the awaiting-approval state the
        # registration flow renders (docs/plans/6.0-b2b-company-self-registration.md).
        return if Spree.company_activation_policy.active?(company)

        errors.add(:company, :not_active)
      end

      # Deliberately not memoized. An instance variable survives #reload, so a
      # value cached before a membership was added stays stale for the life of
      # the object — which silently dropped the company at completion. Caching
      # this safely needs the reset-on-reload machinery; the repeated query is
      # the cheaper problem.
      def sole_standing_company
        return nil if store_id.nil?

        Spree::Company.sole_standing_for(store: store, customer: customer)
      end
    end
  end
end
