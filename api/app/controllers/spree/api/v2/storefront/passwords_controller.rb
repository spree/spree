module Spree
  module Api
    module V2
      module Storefront
        class PasswordsController < ::Spree::Api::V2::BaseController
          include Spree::Core::ControllerHelpers::Store

          def create
            user = Spree.user_class.find_by(email: params[:user][:email])

            if user&.send_reset_password_instructions(current_store)
              head :ok
            else
              head :not_found
            end
          end

          def update
            user = Spree.user_class.reset_password_by_token(
              password: params[:user][:password],
              password_confirmation: params[:user][:password_confirmation],
              reset_password_token: params[:id]
            )

            if user.errors.empty?
              head :ok
            else
              render json: { error: user.errors.full_messages.to_sentence }, status: :unprocessable_entity
            end
          end
        end
      end
    end
  end
end
