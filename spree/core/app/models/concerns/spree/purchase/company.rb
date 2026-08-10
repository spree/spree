module Spree
  module Purchase
    # Which business customer a sale is for, shared by Spree::Cart and
    # Spree::Order. The branch is what the sale references; the company is
    # derived from it, so a per-branch address or registration has somewhere to
    # live later without moving this column.
    module Company
      extend ActiveSupport::Concern

      included do
        belongs_to :company_location, class_name: 'Spree::CompanyLocation', optional: true

        # Guarded on the model rather than in the controller so every path is
        # covered — the admin write, a future storefront one, and the console.
        # Companies are store-scoped, so a branch from another store would tax
        # this sale against a business the merchant does not trade as.
        validate :company_location_belongs_to_store
      end

      # @return [Spree::Company, nil]
      def company
        resolved_company_location&.company
      end

      # @return [Boolean] whether this sale is for a business customer
      def b2b?
        resolved_company_location.present?
      end

      # The branch this sale is for. An explicit choice wins; otherwise a buyer
      # who acts for exactly one branch is unambiguous and resolves to it.
      #
      # A buyer who acts for several resolves to nothing, so no company applies
      # and no exemption is claimed — refusing to guess, because guessing would
      # invoice one business for another's purchase.
      #
      # **Provisional — revisit when channels and catalogs are implemented.**
      # That work (docs/plans/6.1-channels-catalogs-b2b.md — filed as 6.1 today,
      # expected to land in 6.0) has the identical question and no answer either:
      # its `Products::ForContext` calls `user_company_location(user, store)`,
      # singular, which the plan never defines. Catalog, negotiated pricing and
      # tax all need the same answer, so it must be settled once and read from
      # one place — otherwise a buyer could browse one company's catalog at its
      # prices while being taxed as another.
      #
      # Until then, staff can set the branch explicitly through the admin order
      # API. A buyer acting for several businesses who checks out unaided gets no
      # company and no exemption, which is why this must not stay as it is.
      #
      # @return [Spree::CompanyLocation, nil]
      def resolved_company_location
        # A placed order answers from what it was stamped with, never by
        # resolving again — otherwise adding a buyer to a company months later
        # would reach back and exempt an order that legitimately charged tax.
        return company_location if is_a?(Spree::Order) && completed?
        return company_location if company_location_id.present?

        sole_customer_location
      end

      private

      def company_location_belongs_to_store
        return if company_location.nil? || store_id.nil?
        return if company_location.store_id == store_id

        errors.add(:company_location, :invalid)
      end

      # Deliberately not memoized. An instance variable survives #reload, so a
      # value cached before a contact was added stays stale for the life of the
      # object — which silently dropped the branch at completion. Caching this
      # safely needs the reset-on-reload machinery; the repeated query is the
      # cheaper problem.
      def sole_customer_location
        return nil if customer.nil?

        locations = customer.company_locations.to_a.uniq
        locations.one? ? locations.first : nil
      end
    end
  end
end
