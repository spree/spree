module Spree
  module Api
    module V1
      class UsersController < Spree::Api::BaseController
        rescue_from Spree::Core::DestroyWithOrdersError, with: :error_during_processing

        def index
          @users = Spree.user_class.accessible_by(current_ability, :show)

          if params[:ids]
            @users = @users.where(id: params[:ids])
          elsif params[:q]
            users_with_ship_address = @users.with_address(params[:q][:ship_address_firstname_start])
            users_with_bill_address = @users.with_address(params[:q][:ship_address_firstname_start], :bill_address)

            users_with_addresses_ids = (users_with_ship_address.ids + users_with_bill_address.ids).compact.uniq
            @users = @users.with_email_or_addresses_ids(params[:q][:email_start], users_with_addresses_ids)
          end

          @users = @users.page(params[:page]).per(params[:per_page])
          expires_in 15.minutes, public: true
          headers['Surrogate-Control'] = "max-age=#{15.minutes}"
          respond_with(@users)
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
