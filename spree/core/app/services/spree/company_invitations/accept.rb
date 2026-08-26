module Spree
  module CompanyInvitations
    # Turns a pending invitation into a membership. Two ways in, converging
    # here: a registration payload — run through the single customer-creation
    # workflow — or an already-authenticated customer whose account the
    # invitation binds to. Either way the membership is created, the
    # acceptance stamped and the token spent.
    class Accept
      prepend Spree::ServiceModule::Base

      # @param invitation [Spree::CompanyInvitation]
      # @param customer [Object, nil] an authenticated customer accepting
      # @param customer_attributes [Hash, nil] registration payload for a new
      #   customer; the account is created with the invited email
      # @return [Spree::ServiceModule::Result] value is the created
      #   Spree::CompanyMembership
      def call(invitation:, customer: nil, customer_attributes: nil)
        return failure(invitation, :invitation_not_pending) unless invitation.pending?
        # The token names one person. Without this, anyone holding it could
        # spend it from an unrelated signed-in account and take standing over
        # the company — which authorizes buying, reading the subtree's orders
        # and revoking the other members' invitations.
        return failure(invitation, :invitation_email_mismatch) unless invited_email?(invitation, customer)

        if customer.nil?
          result = Spree.customer_create_workflow.call(
            store: invitation.store,
            **(customer_attributes || {}).to_h.symbolize_keys.merge(email: invitation.email)
          )
          return failure(result.value, result.error) if result.failure?

          customer = result.value
        end

        membership = nil
        ApplicationRecord.transaction do
          membership = invitation.company.memberships.where(customer: customer).first_or_create!
          invitation.update!(accepted_at: Time.current, customer: customer)
        end

        invitation.publish_event('company_invitation.accepted')

        success(membership)
      rescue ActiveRecord::RecordInvalid => e
        failure(e.record)
      end

      private

      # Compared the way the invitation stores it — normalized, since a
      # customer signed up as "Buyer@Example.com" is the same person the
      # invitation went to.
      def invited_email?(invitation, customer)
        return true if customer.nil?

        customer.email.to_s.strip.downcase == invitation.email
      end
    end
  end
end
