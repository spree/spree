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
        # authority is the admin credential rather than a membership.
        validate :customer_has_standing_over_company,
                 if: -> { is_a?(Spree::Cart) && company_id_changing? && customer_id.present? }
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
        return company if company_id.present?

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
        return if customer.standing_for?(company)

        errors.add(:company, :invalid)
      end

      # Deliberately not memoized. An instance variable survives #reload, so a
      # value cached before a membership was added stays stale for the life of
      # the object — which silently dropped the company at completion. Caching
      # this safely needs the reset-on-reload machinery; the repeated query is
      # the cheaper problem.
      def sole_standing_company
        return nil if customer.nil? || store_id.nil?

        # Scoped to this sale's store. Customers are global, so without this a
        # buyer who is a member at a company in another store would resolve to
        # that business here — and its registration and exemption certificates
        # would then decide this sale's tax.
        memberships = customer.company_memberships.
                      joins(:company).
                      merge(Spree::Company.where(store_id: store_id)).
                      to_a.uniq

        memberships.one? ? memberships.first.company : nil
      end
    end
  end
end
