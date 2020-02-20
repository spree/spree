module Spree
  module Admin
    class StoresController < Spree::Admin::BaseController
      before_action :load_store, only: [:new, :edit, :update]
      before_action :set_default_currency, only: :new

      def index
        @stores = Spree::Store.all
      end

      def create
        @store = Spree::Store.new(permitted_store_params)

        if @store.save
          flash[:success] = flash_message_for(@store, :successfully_created)
          redirect_to admin_stores_path
        else
          flash[:error] = "#{Spree.t('store_errors.unable_to_create')}: #{@store.errors.full_messages.join(', ')}"
          render :new
        end
      end

      def update
        @store.assign_attributes(permitted_store_params)

        if @store.save
          flash[:success] = flash_message_for(@store, :successfully_updated)
          redirect_to admin_stores_path
        else
          flash[:error] = "#{Spree.t('store_errors.unable_to_update')}: #{@store.errors.full_messages.join(', ')}"
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
          render plain: "#{Spree.t('store_errors.unable_to_delete')}: #{@store.errors.full_messages.join(', ')}", status: :unprocessable_entity
        end
      end

      def set_default
        store = Spree::Store.find(params[:id])
        stores = Spree::Store.where.not(id: params[:id])

        ApplicationRecord.transaction do
          store.update(default: true)
          stores.update_all(default: false)
        end

        if store.errors.empty?
          flash[:success] = Spree.t(:store_set_as_default, store: store.name)
        else
          flash[:error] = "#{Spree.t(:store_not_set_as_default, store: store.name)} #{store.errors.full_messages.join(', ')}"
        end

        redirect_to admin_stores_path
      end

      protected

      def permitted_store_params
        params.require(:store).permit(permitted_store_attributes)
      end

      private

      def load_store
        @store = Spree::Store.find_by(id: params[:id]) || Spree::Store.new
      end

      def set_default_currency
        @store.default_currency = Spree::Config[:currency]
      end
    end
  end
end
