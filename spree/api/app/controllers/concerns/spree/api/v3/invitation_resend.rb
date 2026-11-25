module Spree
  module Api
    module V3
      # Answers a request to send an invitation again, the same way on every
      # API: the invitation when the email went out, otherwise why not — the
      # real refusal (expired, accepted or revoked) or the record's errors.
      module InvitationResend
        private

        # @yieldparam invitation [Spree::Invitation] the invitation, sent again
        # @yieldreturn [Hash] its serialized form
        def render_invitation_resend(invitation)
          if invitation.resend!
            render json: yield(invitation)
          elsif invitation.resend_refusal
            render_error(
              code: ErrorHandler::ERROR_CODES[:processing_error],
              message: I18n.t("spree.invitation_#{invitation.resend_refusal}"),
              status: :unprocessable_content
            )
          else
            render_validation_error(invitation.errors)
          end
        end
      end
    end
  end
end
