module Spree
  module Vendors
    # Invites someone to run a vendor: sends them an invitation to the vendor's
    # own team and marks the vendor as awaiting their acceptance.
    #
    # Accepting the invitation is what creates the membership — that happens on
    # the existing invitation rail, not here, so this workflow only opens the
    # door.
    class Invite < Spree::Workflow
      hooks :validate, :after_invite

      # The invitation sent, so hook handlers can reach it.
      attr_reader :invitation

      # @param vendor [Spree::Vendor]
      # @param email [String] who to invite
      # @param inviter [Object] the staff member inviting them
      # @param role [Spree::Role, nil] the vendor role they accept into;
      #   defaults to the vendor's own admin role
      def perform(vendor:, email:, inviter:, role: nil)
        super

        step :ensure_invitable
        run_hooks :validate

        ApplicationRecord.transaction do
          step :send_invitation
          step :mark_invited
        end

        run_hooks :after_invite
        vendor.publish_event('vendor.invited')
        success(vendor.reload)
      end

      private

      # Re-inviting is deliberate: an invitation expires, or the first one goes
      # to the wrong address. What cannot be re-opened is a vendor already
      # trading or already turned away.
      def ensure_invitable
        return if vendor.pending? || vendor.invited? || vendor.canceled?

        failure(vendor, :not_invitable)
      end

      # The invitation validates that the role is one this vendor owns, so a
      # role naming somewhere else comes back as a 422 rather than access
      # granted elsewhere.
      def send_invitation
        @invitation = vendor.invitations.new(email: email, role: role, inviter: inviter)

        failure(@invitation, @invitation.errors) unless @invitation.save
      end

      def mark_invited
        vendor.update!(status: 'invited')
      end
    end
  end
end
