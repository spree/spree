module Spree
  module Admin
    class AdminUsersController < BaseController
      skip_before_action :authorize_admin, only: [:new, :create]

      before_action :load_resource
      before_action :load_invitation, only: [:new, :create]
      before_action :load_admin_user, only: [:edit, :update, :destroy]

      layout :choose_layout

      # GET /admin/admin_users
      def index
        params[:q] ||= {}
        params[:q][:s] ||= 'created_at asc'
        @search = scope.ransack(params[:q])
        @collection = @search.result
      end

      def show
        @admin_user = scope.find(params[:id])
      end

      # GET /admin/admin_users/new?token=<token>
      # this is a self signup flow for admin users from the invitation email
      def new
        @admin_user = Spree.admin_user_class.new
        @admin_user.email = @invitation.email
      end

      # POST /admin/admin_users
      # this is a self signup flow for admin users from the invitation email
      def create
        @admin_user = Spree.admin_user_class.new(permitted_params)
        @admin_user.spree_role_ids = @invitation.role_ids
        if @admin_user.save && @invitation.accept!
          @invitation.update!(invitee: @admin_user)

          # Automatically log in the user after successful signup
          # if Devise is installed
          if defined?(sign_in)
            sign_in(Spree.admin_user_class.model_name.singular_route_key, @admin_user)
          end
          redirect_to spree.admin_path
        else
          render :new, status: :unprocessable_entity
        end
      end

      # GET /admin/admin_users/:id/edit
      def edit
        authorize! :update, @admin_user
      end

      # PUT /admin/admin_users/:id
      def update
        authorize! :update, @admin_user

        if @admin_user.update(permitted_params.merge(spree_role_ids: []))
          redirect_to spree.edit_admin_admin_user_path(@admin_user), status: :see_other, notice: flash_message_for(@admin_user, :successfully_updated)
        else
          render :edit, status: :unprocessable_entity
        end
      end

      private

      def permitted_params
        params.require(:admin_user).permit(:email, :password, :password_confirmation, :first_name, :last_name)
      end

      # load the resource to be used for authorization
      # this can be extended to load different resources, eg vendor users
      def load_resource
        @resource = current_store
      end

      def load_invitation
        raise ActiveRecord::RecordNotFound if params[:token].blank?

        @invitation = Spree::Invitation.pending.not_expired.find_by!(token: params[:token])
      end

      def scope
        @resource.admin_users.accessible_by(current_ability, :manage)
      end

      def choose_layout
        @invitation.present? ? 'spree/minimal' : 'spree/admin'
      end

      def load_admin_user
        @admin_user = scope.find(params[:id])
      end
    end
  end
end
