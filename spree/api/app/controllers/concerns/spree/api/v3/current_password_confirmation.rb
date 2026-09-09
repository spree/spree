module Spree
  module Api
    module V3
      # Re-asks for the account password before something irreversible.
      #
      # Shared because the check must not drift: a customer class may
      # authenticate through `valid_password?` or `authenticate` depending on
      # what the host app swapped in, and a second copy of that ladder is a
      # second thing to remember when it changes. One of the two call sites
      # gates permanent erasure.
      module CurrentPasswordConfirmation
        extend ActiveSupport::Concern

        private

        # @return [Boolean] whether `current_password` matches the signed-in
        #   account. False when the parameter is missing — an absent password
        #   is not a correct one.
        def valid_current_password?
          return false if params[:current_password].blank?

          if current_user.respond_to?(:valid_password?)
            current_user.valid_password?(params[:current_password])
          elsif current_user.respond_to?(:authenticate)
            current_user.authenticate(params[:current_password]).present?
          else
            false
          end
        end

        def render_current_password_invalid
          render_error(
            code: ErrorHandler::ERROR_CODES[:current_password_invalid],
            message: Spree.t(:current_password_invalid, scope: :api),
            status: :unprocessable_content
          )
        end
      end
    end
  end
end
