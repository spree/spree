module Spree
  module Admin
    class AdminUsersController < BaseController
      include Spree::Admin::SettingsConcern

      skip_before_action :authorize_admin, only: [:new, :create]
      before_action :load_parent, except: [:new, :create]
      before_action :load_roles, except: [:index]
      before_action :load_invitation, only: [:new, :create]
      before_action :load_admin_user, only: [:show, :edit, :update, :destroy]

      helper_method :object_url

      # GET /admin/admin_users
      def index
        params[:q] ||= {}
        params[:q][:s] ||= 'created_at asc'
        @search = scope.includes(role_users: :role, avatar_attachment: :blob).
                  where(role_users: { resource: @parent }).
                  ransack(params[:q])
        @collection = @search.result
      end

      # GET /admin/admin_users/:id
      def show
        authorize! :read, @admin_user
        @role_users = @admin_user.role_users.includes(:role).where(resource: @parent)

        add_breadcrumb @admin_user.email, spree.admin_admin_user_path(@admin_user)
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
        @invitation.invitee = @admin_user
        if @admin_user.save && @invitation.accept!
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

        permitted_params = params.require(:admin_user).permit(permitted_user_attributes | [spree_role_ids: []])

        if @admin_user.update(permitted_params)
          redirect_to spree.admin_admin_user_path(@admin_user), status: :see_other, notice: flash_message_for(@admin_user, :successfully_updated)
        else
          render :edit, status: :unprocessable_entity
        end
      end

      # DELETE /admin/admin_users/:id
      def destroy
        authorize! :destroy, @admin_user
        if @admin_user.destroy
          redirect_to spree.admin_admin_users_path, status: :see_other, notice: flash_message_for(@admin_user, :successfully_removed)
        else
          flash[:error] = @admin_user.errors.full_messages.to_sentence
          redirect_to spree.admin_admin_users_path, status: :see_other
        end
      end

      private

      def permitted_params
        params.require(:admin_user).permit(:email, :password, :password_confirmation, :first_name, :last_name)
      end

      def load_invitation
        raise ActiveRecord::RecordNotFound if params[:token].blank?

        @invitation = Spree::Invitation.pending.not_expired.find_by!(token: params[:token])
      end

      def load_parent
        @parent = current_store
      end

      def scope
        @parent.users.accessible_by(current_ability, :manage)
      end

      def load_admin_user
        @admin_user = Spree.admin_user_class.accessible_by(current_ability).find(params[:id])
      end

      # for self signup flow, we use the minimal layout
      def choose_layout
        @invitation.present? ? 'spree/minimal' : 'spree/admin_settings'
      end

      def load_roles
        @roles = Spree::Role.accessible_by(current_ability)
      end

      def model_class
        Spree.admin_user_class
      end

      def object_url
        spree.admin_admin_user_path(@admin_user)
      end
    end
  end
end
