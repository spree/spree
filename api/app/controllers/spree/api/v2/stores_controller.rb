module Spree
  module Api
    class StoresController < Spree::Api::BaseController

      before_filter :get_store, except: [:index, :create]

      def index
        authorize! :read, Store
        @stores = Store.accessible_by(current_ability, :read).all
        render json: @stores
      end

      def create
        authorize! :create, Store
        @store = Store.new(store_params)
        @store.code = params[:store][:code]
        if @store.save
          render json: @store, status: 201
        else
          invalid_resource!(@store)
        end
      end

      def update
        authorize! :update, @store
        if @store.update_attributes(store_params)
          render json: @store
        else
          invalid_resource!(@store)
        end
      end

      def show
        authorize! :read, @store
        render json: @store
      end

      def destroy
        authorize! :destroy, @store
        @store.destroy
        if @store.errors.any?
          invalid_resource!(@store)
        else
          render json: @store, status: 204
        end
      end

      private

      def get_store
        @store = Store.find(params[:id])
      end

      def store_params
        params.require(:store).permit(permitted_store_attributes)
      end
    end
  end
end
