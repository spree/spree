module Spree
  module Admin
    class AdminUsersController < BaseController
      skip_before_action :authorize_admin
      before_action :load_invitation

      layout 'spree/minimal'

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

      private

      def permitted_params
        params.require(:admin_user).permit(:email, :password, :password_confirmation, :first_name, :last_name)
      end

      def load_invitation
        raise ActiveRecord::RecordNotFound if params[:token].blank?

        @invitation = Spree::Invitation.pending.not_expired.find_by!(token: params[:token])
        @resource = @invitation.resource
      end
    end
  end
end
