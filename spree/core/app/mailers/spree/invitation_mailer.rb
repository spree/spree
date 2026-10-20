module Spree
  class InvitationMailer < BaseMailer
    # invitation email, sending email to the invited to let them know they have been invited to join a store/account/seller
    def invitation_email(invitation)
      @invitation = invitation
      # The shared header/footer and from/reply-to addresses read
      # current_store — without this, background delivery falls back to the
      # default store's branding on multi-store installs.
      @current_store = invitation.store
      with_store_locale(invitation.store) do
        mail_template(
          { invitation: email_data(invitation, Spree::Emails::InvitationSerializer), accept_url: accept_url(invitation) },
          to: invitation.email
        )
      end
    end

    # sending email to the inviter to let them know the invitee has accepted the invitation
    def invitation_accepted(invitation)
      @invitation = invitation
      @current_store = invitation.store
      with_store_locale(invitation.store) do
        mail_template(
          { invitation: email_data(invitation, Spree::Emails::InvitationSerializer) },
          to: invitation.inviter.email
        )
      end
    end

    private

    # The legacy `spree_admin` gem's own acceptance page when it is installed,
    # otherwise the dashboard's.
    def accept_url(invitation)
      spree_routes = Spree::Core::Engine.routes.url_helpers

      if spree_routes.respond_to?(:admin_invitation_url)
        spree_routes.admin_invitation_url(invitation, token: invitation.token, host: invitation.store.formatted_url)
      else
        # Built with the mailer's own URL options, as the view built it before.
        ensure_default_action_mailer_url_host
        main_app.admin_invitation_acceptance_url(invitation)
      end
    end
  end
end
