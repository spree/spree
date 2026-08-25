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
      # @param role [String, nil] cosmetic membership label
      # @param metadata [Hash, nil] extension payload carried onto the record
      # @return [Spree::ServiceModule::Result] value is the created
      #   Spree::CompanyMembership or Spree::CompanyInvitation
      def call(company:, email:, inviter: nil, role: nil, metadata: nil)
        normalized_email = email.to_s.strip.downcase
        customer = Spree.customer_class.find_by(email: normalized_email)

        record =
          if customer
            attributes = { customer: customer }
            attributes[:role] = role if role.present?
            attributes[:metadata] = metadata if metadata.present?
            company.memberships.new(attributes)
          else
            company.invitations.new(email: normalized_email, inviter: inviter, metadata: metadata)
          end

        record.save ? success(record) : failure(record)
      end
    end
  end
end
