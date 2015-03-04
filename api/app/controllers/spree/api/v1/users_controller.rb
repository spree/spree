module Spree
  module Api
    module V1
      class UsersController < Spree::Api::BaseController

        def index
          @users = Spree.user_class.accessible_by(current_ability,:read).ransack(params[:q]).result.page(params[:page]).per(params[:per_page])
          respond_with(@users)
        end

        def show
          respond_with(user)
        end

        def new
        end

        def create
          authorize! :create, Spree.user_class
          @user = Spree.user_class.new(user_params)
          if @user.save
            respond_with(@user, :status => 201, :default_template => :show)
          else
            invalid_resource!(@user)
          end
        end

        def update
          authorize! :update, user
          if user.update_attributes(user_params)
            respond_with(user, :status => 200, :default_template => :show)
          else
            invalid_resource!(user)
          end
        end

        def destroy
          authorize! :destroy, user
          user.destroy
          respond_with(user, :status => 204)
        end

        private

        def user
          @user ||= Spree.user_class.accessible_by(current_ability, :read).find(params[:id])
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
