module Spree
  module Admin
    class ResourceUsersController < BaseController
      before_action :load_parent
      before_action :load_resource_user, only: [:edit, :update, :destroy]

      # DELETE /admin/store/resource_users/:id
      def destroy
        authorize! :destroy, @resource_user

        @resource_user.destroy
        redirect_back fallback_location: spree.admin_admin_users_path, status: :see_other, notice: flash_message_for(@resource_user, :successfully_removed)
      end

      private

      # load the resource to be used for authorization
      # this can be extended to load different resources, eg vendor users
      def load_parent
        @parent = current_store
      end

      def scope
        @parent.resource_users.accessible_by(current_ability, :manage)
      end

      def load_resource_user
        @resource_user = scope.find(params[:id])
      end

      def model_class
        Spree::ResourceUser
      end
    end
  end
end
