module Spree
  module Api
    module V2
      class UsersController < Spree::Api::BaseController

        def index
          @users = Spree.user_class.accessible_by(current_ability,:read).ransack(params[:q]).result.page(params[:page]).per(params[:per_page])
          render json: @users, meta: pagination(@users)
        end

        def show
          render json: user, serializer: Spree::UserSerializer
        end

        def new
        end

        def create
          authorize! :create, Spree.user_class
          @user = Spree.user_class.new(user_params)
          if @user.save
            render json: @user, serializer: Spree::UserSerializer, status: 201
          else
            invalid_resource!(@user)
          end
        end

        def update
          authorize! :update, user
          if user.update_attributes(user_params)
            render json: user, serializer: Spree::UserSerializer
          else
            invalid_resource!(user)
          end
        end

        def destroy
          authorize! :destroy, user
          user.destroy
          render json: user, status: 204
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
