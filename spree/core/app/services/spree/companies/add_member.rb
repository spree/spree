module Spree
  module Companies
    # Adds a person to a company node by email — the single convergent path
    # behind both the dashboard's and the storefront's "add member".
    #
    # An email that matches an existing customer becomes a membership
    # immediately; an unknown email becomes a {Spree::CompanyInvitation},
    # whose creation event sends the invite mail. Extension payloads (e.g. an
    # Enterprise role reference) ride +metadata+ on either record.
    class AddMember
      prepend Spree::ServiceModule::Base

      # @param company [Spree::Company]
      # @param email [String]
      # @param inviter [Object, nil] the inviting customer, nil when staff
      # @param metadata [Hash, nil] extension payload — carried on the
      #   invitation only, where Enterprise reads it back on acceptance
      #   (memberships have no metadata column; a direct-membership payload is
      #   applied by the caller through the `company_membership.form_fields`
      #   contract, not stored here)
      # @return [Spree::ServiceModule::Result] value is the created
      #   Spree::CompanyMembership or Spree::CompanyInvitation
      def call(company:, email:, inviter: nil, metadata: nil)
        normalized_email = email.to_s.strip.downcase
        customer = Spree.customer_class.find_by(email: normalized_email)

        record =
          if customer
            company.memberships.new(customer: customer)
          else
            company.invitations.new(email: normalized_email, inviter: inviter, metadata: metadata)
          end

        record.save ? success(record) : failure(record)
      end
    end
  end
end
