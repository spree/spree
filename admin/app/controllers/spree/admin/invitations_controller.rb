module Spree
  module Admin
    class InvitationsController < BaseController
      skip_before_action :authorize_admin, only: [:show]

      before_action :load_invitation_resource
      before_action :load_invitation, only: [:accept, :destroy]
      before_action :load_roles, only: [:new, :create]

      layout :choose_layout

      # GET /admin/invitations
      def index
        params[:q] ||= {}
        params[:q][:s] ||= 'created_at desc'
        @search = scope.includes(:inviter, :roles).ransack(params[:q])
        @collection = @search.result
      end

      # GET /admin/invitations/new
      def new
        authorize! :manage, @resource

        @invitation = Spree::Invitation.new
        @invitation.resource = @resource
        @invitation.inviter = try_spree_current_user
      end

      # POST /admin/invitations
      def create
        authorize! :create, Spree::Invitation
        authorize! :manage, @resource

        @invitation = Spree::Invitation.new(permitted_params)
        @invitation.resource = @resource
        @invitation.inviter = try_spree_current_user

        if @invitation.save
          respond_to do |format|
            format.html { redirect_to spree.admin_invitations_path, notice: flash_message_for(@invitation, :successfully_created) }
            format.turbo_stream
          end
        else
          render :new, status: :unprocessable_entity
        end
      end

      # GET /admin/invitations/:id?token=:token
      def show
        begin
          @invitation = Spree::Invitation.pending.not_expired.find_by!(id: params[:id], token: params[:token])

          if try_spree_current_user != @invitation.invitee
            raise ActiveRecord::RecordNotFound
          end
        rescue ActiveRecord::RecordNotFound
          redirect_to spree.root_path, alert: Spree.t('invalid_or_expired_invitation')
          return
        end

        # if there's no current user, redirect to the new admin user path so they can sign up
        unless try_spree_current_user
          redirect_to spree.new_admin_admin_user_path(token: @invitation.token), status: :see_other
          return
        end
      end

      # PUT /admin/invitations/:id/accept
      def accept
        @invitation = try_spree_current_user.invitations.pending.not_expired.find(params[:id])
        @invitation.accept!
        redirect_to spree.admin_invitations_path, notice: Spree.t('invitation_accepted')
      end

      # PUT /admin/invitations/:id/resend
      def resend
        @invitation = scope.find(params[:id])
        @invitation.resend!
        redirect_to spree.admin_invitations_path, notice: Spree.t('invitation_resent')
      end

      # DELETE /admin/invitations/:id
      def destroy
        authorize! :destroy, @invitation

        @invitation.destroy
        redirect_to spree.admin_invitations_path, notice: flash_message_for(@invitation, :successfully_removed)
      end

      private

      def load_invitation
        @invitation = scope.find(params[:id])
      end

      def load_invitation_resource
        @resource = current_store
      end

      def scope
        Spree::Invitation.accessible_by(current_ability).where(resource: @resource)
      end

      def load_roles
        @roles = Spree::Role.accessible_by(current_ability)
      end

      def permitted_params
        params.require(:invitation).permit(:email, :expires_at, role_ids: [])
      end

      def choose_layout
        action_name == 'show' ? 'spree/minimal' : 'spree/admin'
      end
    end
  end
end
