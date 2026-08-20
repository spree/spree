module Spree
  module Invitations
    # Turns an invitation into access: the invitee gains the role they were
    # invited to, and the invitation is marked accepted.
    #
    # The expiry and invitee checks were state-scoped validations on the old
    # machine, which meant an expired invitation became a record that refused
    # to save. As guards they refuse the acceptance itself, so the invitation
    # is left untouched and still pending.
    class Accept < Spree::Workflow
      hooks :validate, :after_accept

      # @param invitation [Spree::Invitation]
      # @return [Spree::ServiceModule::Result] value is the invitation
      def perform(invitation:)
        super

        step :ensure_acceptable
        run_hooks :validate

        ApplicationRecord.transaction do
          step :grant_role
          step :mark_accepted
          run_hooks :after_accept
        end

        invitation.publish_event('invitation.accepted')
        success(invitation)
      end

      private

      def ensure_acceptable
        failure(invitation, :invitation_already_accepted) if invitation.accepted?
        failure(invitation, :invitation_expired) if invitation.expired?
        failure(invitation, :invitation_invitee_missing) if invitation.invitee.blank?
      end

      def grant_role
        invitation.role_user = invitation.resource.add_user(invitation.invitee, invitation.role)
      end

      # One write where the machine did three: the transition, the role_user
      # link and the accepted_at stamp were each their own save.
      def mark_accepted
        failure(invitation) unless invitation.update(status: 'accepted', accepted_at: Time.current)
      end
    end
  end
end
