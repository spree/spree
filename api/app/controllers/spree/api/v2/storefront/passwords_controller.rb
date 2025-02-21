module Spree
  module Api
    module V2
      module Storefront
        class PasswordsController < ::Spree::Api::V2::BaseController
          include Spree::Core::ControllerHelpers::Store

          def create
            user = Spree.user_class.find_by(email: permitted_user_params[:email])

            if user&.send_reset_password_instructions
              head :ok
            else
              head :not_found
            end
          end

          def update
            user = Spree.user_class.reset_password_by_token(
              password: permitted_user_params[:password],
              password_confirmation: permitted_user_params[:password_confirmation],
              reset_password_token: params[:id]
            )

            if user.errors.empty?
              head :ok
            else
              render json: { error: user.errors.full_messages.to_sentence }, status: :unprocessable_entity
            end
          end

          private

          def permitted_user_params
            params.require(:user).permit(:email, :password, :password_confirmation)
          end
        end
      end
    end
  end
end
