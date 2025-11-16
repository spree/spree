module Spree
  module Admin
    class StoreCreditError < StandardError; end

    class StoreCreditsController < Spree::Admin::BaseController
      before_action :load_user
      before_action :load_store_credit, only: [:new, :edit, :update, :destroy]
      before_action :ensure_unused_store_credit, only: [:update]
      helper_method :collection_url

      def index
        collection_scope = scope.includes(:created_by).order(created_at: :desc)
        @pagy, @store_credits = pagy(collection_scope, items: params[:per_page] || Spree::Admin::Config[:admin_records_per_page])

        @collection = @store_credits
      end

      def show
        @store_credit = scope.find(params[:id])
        @store_credit_events = @store_credit.store_credit_events.reverse_chronological.includes(:originator, :order)
      end

      def create
        @store_credit = @user.store_credits.build(
          permitted_store_credit_params.merge(
            created_by: try_spree_current_user,
            action_originator: try_spree_current_user,
            store: current_store
          )
        )

        if @store_credit.save
          flash[:success] = flash_message_for(@store_credit, :successfully_created)
          redirect_to spree.admin_user_path(@user)
        else
          flash[:error] = Spree.t('store_credit.errors.unable_to_create')
          render :new, status: :unprocessable_entity
        end
      end

      def update
        @store_credit.assign_attributes(permitted_store_credit_params)

        if @store_credit.save
          flash[:success] = flash_message_for(@store_credit, :successfully_updated)
          redirect_to spree.admin_user_store_credit_path(@user, @store_credit)
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

        redirect_to spree.admin_user_path(@user)
      end

      protected

      def permitted_store_credit_params
        params.require(:store_credit).permit(permitted_store_credit_attributes)
      end

      private

      def load_user
        @user = Spree.user_class.find_by(id: params[:user_id])

        unless @user
          flash[:error] = Spree.t(:user_not_found)
          redirect_to spree.admin_path
        end

        @breadcrumb_icon = 'users'
        add_breadcrumb Spree.t(:customers), :admin_users_path
        add_breadcrumb @user.name, spree.admin_user_path(@user)
      end

      def load_store_credit
        @store_credit = scope.find_by(id: params[:id]) || scope.new
        @object = @store_credit
      end

      def scope
        current_store.store_credits.where(user: @user)
      end

      def ensure_unused_store_credit
        unless @store_credit.amount_used.zero?
          raise StoreCreditError, Spree.t('store_credit.errors.cannot_change_used_store_credit')
        end
      end

      def collection_url
        spree.admin_user_store_credits_path(@user)
      end
    end
  end
end
