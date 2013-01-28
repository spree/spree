module Spree
  module Api
    class UsersController < Spree::Api::BaseController
      respond_to :json

      def index
        @users = Spree.user_class.accessible_by(current_ability,:read).ransack(params[:q]).result.page(params[:page]).per(params[:per_page])
        respond_with(@users)
      end

      def show
        authorize! :show, user
        respond_with(user)
      end

      def new
      end

      def create
        authorize! :create, Spree.user_class
        @user = Spree.user_class.new(params[:user])
        if @user.save
          respond_with(@user, :status => 201, :default_template => :show)
        else
          invalid_resource!(@user)
        end
      end

      def update
        authorize! :update, user
        if user.update_attributes(params[:user])
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
        @user ||= Spree.user_class.find(params[:id])
      end
    end
  end
end
