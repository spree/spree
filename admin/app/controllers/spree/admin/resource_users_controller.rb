module Spree
  module Admin
    class ResourceUsersController < BaseController
      before_action :load_parent
      before_action :load_resource_user, only: [:edit, :update, :destroy]

      # GET /admin/store/resource_users
      def index
        params[:q] ||= {}
        params[:q][:s] ||= 'created_at asc'
        @search = scope.includes(user: [:spree_roles, avatar_attachment: :blob]).ransack(params[:q])
        @collection = @search.result
      end

      # GET /admin/store/resource_users/:id
      def show
        @resource_user = scope.find(params[:id])
        @admin_user = @resource_user.user
      end

      # GET /admin/store/resource_users/:id/edit
      def edit
        authorize! :update, @resource_user
      end

      # PUT /admin/store/resource_users/:id
      def update
        authorize! :update, @resource_user

        if @admin_user.update(permitted_params.merge(spree_role_ids: []))
          redirect_to spree.edit_admin_admin_user_path(@admin_user), status: :see_other, notice: flash_message_for(@admin_user, :successfully_updated)
        else
          render :edit, status: :unprocessable_entity
        end
      end

      # DELETE /admin/store/resource_users/:id
      def destroy
        authorize! :destroy, @resource_user

        @resource_user.destroy
        redirect_to [:admin, @parent, :resource_users], status: :see_other, notice: flash_message_for(@admin_user, :successfully_deleted)
      end

      private

      def permitted_params
        params.require(:admin_user).permit(:email, :first_name, :last_name, spree_role_ids: [])
      end

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
        @admin_user = @resource_user.user
      end

      def model_class
        Spree::ResourceUser
      end
    end
  end
end
