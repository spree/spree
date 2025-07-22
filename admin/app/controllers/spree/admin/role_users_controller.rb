module Spree
  module Admin
    class RoleUsersController < BaseController
      before_action :load_parent
      before_action :load_role_user, only: [:edit, :update, :destroy]

      # DELETE /admin/store/role_users/:id
      def destroy
        authorize! :destroy, @role_user

        @role_user.destroy
        redirect_back fallback_location: spree.admin_admin_users_path, status: :see_other, notice: flash_message_for(@role_user, :successfully_removed)
      end

      private

      # load the resource to be used for authorization
      # this can be extended to load different resources, eg vendor users
      def load_parent
        @parent = current_store
      end

      def scope
        @parent.role_users.accessible_by(current_ability, :manage)
      end

      def load_role_user
        @role_user = scope.find(params[:id])
      end

      def model_class
        Spree::RoleUser
      end
    end
  end
end
