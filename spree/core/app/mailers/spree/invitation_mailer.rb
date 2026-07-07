module Spree
  class InvitationMailer < BaseMailer
    # invitation email, sending email to the invited to let them know they have been invited to join a store/account/vendor
    def invitation_email(invitation)
      @invitation = invitation
      # The shared header/footer and from/reply-to addresses read
      # current_store — without this, background delivery falls back to the
      # default store's branding on multi-store installs.
      @current_store = invitation.store
      with_store_locale(invitation.store) do
        mail(to: invitation.email,
             from: from_address,
             reply_to: reply_to_address,
             subject: Spree.t('invitation_mailer.invitation_email.subject',
                              resource_name: invitation.resource&.name))
      end
    end

    # sending email to the inviter to let them know the invitee has accepted the invitation
    def invitation_accepted(invitation)
      @invitation = invitation
      @current_store = invitation.store
      with_store_locale(invitation.store) do
        mail(to: invitation.inviter.email,
             from: from_address,
             reply_to: reply_to_address,
             subject: Spree.t('invitation_mailer.invitation_accepted.subject',
                              invitee_name: invitation.invitee&.name,
                              resource_name: invitation.resource&.name))
      end
    end
  end
end
