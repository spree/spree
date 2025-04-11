module Spree
  class InvitationMailer < BaseMailer
    # invitation email, sending email to the invited to let them know they have been invited to join a store/account/vendor
    def invitation_email(invitation)
      @invitation = invitation
      mail(to: invitation.email, subject: Spree.t('invitation_mailer.invitation_email.subject', resource_name: invitation.resource.name))
    end

    # accept/reject, sending email to the invited to let them know the status of their invitation
    def invitation_accepted(invitation)
      @invitation = invitation
      mail(to: invitation.inviter.email, subject: Spree.t('invitation_mailer.invitation_accepted.subject', invitee_name: invitation.email, resource_name: invitation.resource.name))
    end
  end
end
