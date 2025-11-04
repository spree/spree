module Spree
  module Api
    module V3
      module Storefront
        class AuthController < BaseController
          include Spree::Api::V3::Storefront::Authentication

          skip_before_action :authenticate_user, only: [:create, :register]
          before_action :require_authentication!, only: [:refresh]

          # POST /api/v3/storefront/auth/login
          def create
            user = Spree.user_class.find_by(email: params[:email])

            if user&.valid_password?(params[:password])
              token = generate_jwt(user)
              render json: {
                token: token,
                user: user_serializer.new(user, serializer_context).as_json
              }
            else
              render json: { error: 'Invalid email or password' }, status: :unauthorized
            end
          end

          # POST /api/v3/storefront/auth/register
          def register
            user = Spree.user_class.new(registration_params)

            if user.save
              token = generate_jwt(user)
              render json: {
                token: token,
                user: user_serializer.new(user, serializer_context).as_json
              }, status: :created
            else
              render_errors(user.errors)
            end
          end

          # POST /api/v3/storefront/auth/refresh
          def refresh
            token = generate_jwt(current_user)
            render json: {
              token: token,
              user: user_serializer.new(current_user, serializer_context).as_json
            }
          end

          protected

          def serializer_context
            {
              store: current_store,
              locale: current_locale
            }
          end

          private

          def registration_params
            params.require(:user).permit(:email, :password, :password_confirmation, :first_name, :last_name)
          end

          def user_serializer
            Spree::Api::Dependencies.v3_storefront_user_serializer.constantize
          end
        end
      end
    end
  end
end
