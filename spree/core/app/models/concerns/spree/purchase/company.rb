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
      # **Provisional.** Choosing between several branches is the same question
      # docs/plans/6.1-channels-catalogs-b2b.md leaves open for product
      # visibility (its `user_company_location` helper is referenced but never
      # defined), and that plan defers buyer authority to a dedicated B2B plan.
      # Whatever it settles on should replace this.
      #
      # @return [Spree::CompanyLocation, nil]
      def resolved_company_location
        return company_location if company_location_id.present?

        sole_customer_location
      end

      private

      def sole_customer_location
        return nil if customer.nil?

        locations = customer.company_locations.to_a.uniq
        locations.one? ? locations.first : nil
      end
    end
  end
end
