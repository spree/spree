module Spree
  module Api
    module V1
      class UsersController < Spree::Api::BaseController
        rescue_from Spree::Core::DestroyWithOrdersError, with: :error_during_processing

        def index
          users

          if params[:ids]
            load_users_by_ids
          elsif params.dig(:q, :ship_address_firstname_start)
            load_users_by_address
          elsif params.dig(:q, :email_start)
            load_users_by_email
          end

          prepare_index_response
          respond_with(@users)
        end

        def users
          @users ||= Spree.user_class.accessible_by(current_ability, :show)
        end

        def load_users_by_ids
          @users = @users.where(id: params[:ids])
        end

        def load_users_by_address
          address_params = params[:q][:ship_address_firstname_start] ||
            params[:q][:ship_address_lastname_start] ||
            params[:q][:bill_address_firstname_start] ||
            params[:q][:bill_address_lastname_start]
          @users = @users.with_email_or_address(params[:q][:email_start], address_params)
        end

        def load_users_by_email
          @users = @users.with_email(params[:q][:email_start])
        end

        def paginate_users
          @users = @users.page(params[:page]).per(params[:per_page])
        end

        def prepare_index_response
          paginate_users
          expires_in 15.minutes, public: true
          headers['Surrogate-Control'] = "max-age=#{15.minutes}"
        end

        def show
          respond_with(user)
        end

        def new; end

        def create
          authorize! :create, Spree.user_class
          @user = Spree.user_class.new(user_params)
          if @user.save
            respond_with(@user, status: 201, default_template: :show)
          else
            invalid_resource!(@user)
          end
        end

        def update
          authorize! :update, user
          if user.update(user_params)
            respond_with(user, status: 200, default_template: :show)
          else
            invalid_resource!(user)
          end
        end

        def destroy
          authorize! :destroy, user
          user.destroy
          respond_with(user, status: 204)
        end

        private

        def user
          @user ||= Spree.user_class.accessible_by(current_ability, :show).find(params[:id])
        end

        def user_params
          params.require(:user).permit(permitted_user_attributes |
                                         [bill_address_attributes: permitted_address_attributes,
                                          ship_address_attributes: permitted_address_attributes])
        end
      end
    end
  end
end
