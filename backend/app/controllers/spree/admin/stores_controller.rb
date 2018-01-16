module Spree
  module Admin
    class StoresController < Spree::Admin::BaseController
      before_action :load_store, only: [:new, :edit, :update]

      def index
        @stores = Spree::Store.all
      end

      def create
        @store = Spree::Store.new(permitted_store_params)

        if @store.save
          flash[:success] = flash_message_for(@store, :successfully_created)
          redirect_to admin_stores_path
        else
          flash[:error] = Spree.t('store.errors.unable_to_create')
          render :new
        end
      end

      def update
        @store.assign_attributes(permitted_store_params)

        if @store.save
          flash[:success] = flash_message_for(@store, :successfully_updated)
          redirect_to admin_stores_path
        else
          flash[:error] = Spree.t('store.errors.unable_to_update')
          render :edit
        end
      end

      def destroy
        @store = Spree::Store.find(params[:id])

        if @store.destroy
          flash[:success] = flash_message_for(@store, :successfully_removed)
          respond_with(@store) do |format|
            format.html { redirect_to admin_stores_path }
            format.js { render_js_for_destroy }
          end
        else
          render plain: Spree.t('store.errors.unable_to_delete'), status: :unprocessable_entity
        end
      end

      protected

      def permitted_store_params
        params.require(:store).permit(permitted_store_attributes)
      end

      private

      def load_store
        @store = Spree::Store.find_by(id: params[:id]) || Spree::Store.new
      end
    end
  end
end
