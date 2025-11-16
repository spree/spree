module Spree
  module Admin
    class StoreCreditError < StandardError; end

    class StoreCreditsController < Spree::Admin::ResourceController
      before_action :set_breadcrumbs
      before_action :set_user
      before_action :ensure_unused_store_credit, only: [:update]

      def show
        @store_credit = scope.find(params[:id])
        @store_credit_events = @store_credit.store_credit_events.reverse_chronological.includes(:originator, :order)
      end

      def create
        @store_credit = parent.store_credits.build(
          permitted_resource_params.merge(
            created_by: try_spree_current_user,
            action_originator: try_spree_current_user,
            store: current_store
          )
        )

        if @store_credit.save
          flash[:success] = flash_message_for(@store_credit, :successfully_created)
          redirect_to spree.admin_user_path(parent)
        else
          flash[:error] = Spree.t('store_credit.errors.unable_to_create')
          render :new, status: :unprocessable_entity
        end
      end

      def update
        @store_credit.assign_attributes(permitted_resource_params)

        if @store_credit.save
          flash[:success] = flash_message_for(@store_credit, :successfully_updated)
          redirect_to spree.admin_user_store_credit_path(parent, @store_credit)
        else
          flash[:error] = Spree.t('store_credit.errors.unable_to_update')
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        ensure_unused_store_credit

        if @store_credit.destroy
          flash[:success] = flash_message_for(@store_credit, :successfully_removed)
        else
          flash[:error] = Spree.t('store_credit.errors.unable_to_delete')
        end

        redirect_to spree.admin_user_path(parent)
      end

      protected

      def parent
        @parent ||= Spree.user_class.find_by(id: params[:user_id])
      end

      def parent_data
        {
          model_name: 'spree/user',
          model_class: Spree.user_class,
          find_by: :id
        }
      end

      def permitted_resource_params
        params.require(:store_credit).permit(permitted_store_credit_attributes)
      end

      private

      def set_user
        @user = parent
      end

      def object_url
        spree.admin_user_store_credit_path(parent, @store_credit)
      end

      def set_breadcrumbs
        @breadcrumb_icon = 'users'
        add_breadcrumb Spree.t(:customers), :admin_users_path
        add_breadcrumb parent.name, spree.admin_user_path(parent)
      end

      def ensure_unused_store_credit
        unless @store_credit.amount_used.zero?
          raise StoreCreditError, Spree.t('store_credit.errors.cannot_change_used_store_credit')
        end
      end

      def collection_url
        spree.admin_user_store_credits_path(parent)
      end

      def update_turbo_stream_enabled?
        true
      end
    end
  end
end
