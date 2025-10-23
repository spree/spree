module Spree
  module Admin
    class InvitationsController < BaseController
      include Spree::Admin::SettingsConcern

      skip_before_action :authorize_admin, only: [:show, :accept]

      before_action :load_parent, except: [:show]
      before_action :load_invitation, only: [:destroy]
      before_action :load_roles, only: [:new, :create]

      layout :choose_layout

      # GET /admin/invitations
      def index
        params[:q] ||= {}
        params[:q][:s] ||= 'created_at desc'
        @search = scope.includes(:inviter, :role).ransack(params[:q])
        @collection = @search.result
      end

      # GET /admin/invitations/new
      def new
        authorize! :create, Spree::Invitation
        authorize! :manage, @parent

        @invitation = Spree::Invitation.new
        @invitation.resource = @parent
        @invitation.inviter = try_spree_current_user
      end

      # POST /admin/invitations
      def create
        authorize! :create, Spree::Invitation
        authorize! :manage, @parent

        @invitation = Spree::Invitation.new(permitted_params)
        @invitation.resource = @parent
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
        @invitation = Spree::Invitation.pending.not_expired.find_by!(id: params[:id], token: params[:token])
        @parent = @invitation.resource

        if try_spree_current_user.present?
          unless @invitation.invitee == try_spree_current_user
            raise ActiveRecord::RecordNotFound
          end
        elsif @invitation.invitee.present?
          store_location
          try_to_redirect_to_login_path
        else
          redirect_to spree.new_admin_admin_user_path(token: @invitation.token), status: :see_other
        end
      rescue ActiveRecord::RecordNotFound
        redirect_to spree.root_path, alert: Spree.t('invalid_or_expired_invitation')
        nil
      end

      # PUT /admin/invitations/:id/accept
      def accept
        @invitation = try_spree_current_user.invitations.pending.not_expired.find(params[:id])

        authorize! :accept, @invitation

        @invitation.accept!
        redirect_to spree.admin_path, notice: Spree.t('invitation_accepted')
      end

      # PUT /admin/invitations/:id/resend
      def resend
        @invitation = scope.find(params[:id])
        @invitation.resend!
        redirect_back fallback_location: spree.admin_invitations_path, notice: Spree.t('invitation_resent')
      end

      # DELETE /admin/invitations/:id
      def destroy
        authorize! :destroy, @invitation

        @invitation.destroy
        redirect_back fallback_location: spree.admin_invitations_path, notice: flash_message_for(@invitation, :successfully_removed)
      end

      private

      def load_invitation
        @invitation = scope.find(params[:id])
      end

      def load_parent
        @parent = current_store
      end

      def scope
        Spree::Invitation.accessible_by(current_ability).where(resource: @parent)
      end

      def load_roles
        @roles = Spree::Role.accessible_by(current_ability)
      end

      def permitted_params
        params.require(:invitation).permit(Spree::PermittedAttributes.invitation_attributes)
      end

      def choose_layout
        action_name == 'show' ? 'spree/minimal' : 'spree/admin_settings'
      end

      def model_class
        Spree::Invitation
      end
    end
  end
end
