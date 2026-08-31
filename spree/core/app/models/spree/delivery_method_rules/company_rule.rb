module Spree
  module DeliveryMethodRules
    # Splits freight from parcel by who is buying. A carton or container
    # method set to +required+ disappears from retail carts; a parcel method
    # set to +absent+ disappears from company carts where the merchant wants
    # the two kept apart.
    #
    # Presence only. Which company gets which freight terms is Enterprise
    # territory, and open-source Spree has no company roles to gate on.
    class CompanyRule < Spree::DeliveryMethodRule
      REQUIRED = 'required'.freeze
      ABSENT = 'absent'.freeze
      PRESENCE_OPTIONS = [REQUIRED, ABSENT].freeze

      preference :company_presence, :string, default: nil, nullable: true

      validates :preferred_company_presence, inclusion: { in: PRESENCE_OPTIONS }, allow_blank: true

      def eligible?(package)
        # An unconfigured rule restricts nothing, matching the fail-open
        # convention the other rules follow for half-filled rows.
        return true if preferred_company_presence.blank?

        buying_for_a_company = package.owner&.b2b? || false

        preferred_company_presence == REQUIRED ? buying_for_a_company : !buying_for_a_company
      end
    end
  end
end
