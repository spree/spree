module Spree
  module Admin
    class StorefrontController < BaseController
      include StorefrontBreadcrumbConcern
      add_breadcrumb Spree.t(:settings), :edit_admin_storefront_path

      def edit
        @store = current_store
      end

      def update
        @store = current_store
        if @store.update(store_params)
          remove_assets(%w[favicon_image social_image], object: @store)
          flash[:success] = flash_message_for(@store, :successfully_updated)
        else
          flash[:error] = @store.errors.full_messages.to_sentence
        end

        redirect_to spree.edit_admin_storefront_path
      end

      private

      def store_params
        params.require(:store).permit(
          :preferred_index_in_search_engines,
          :preferred_password_protected, :social_image, :favicon_image, :name,
          :meta_description, :meta_title, :meta_keywords, :seo_robots,
          :facebook, :twitter, :instagram, :linkedin, :youtube, :tiktok, :pinterest,
          :storefront_custom_code_head, :storefront_custom_code_body_start,
          :storefront_custom_code_body_end, :storefront_password, :spotify, :discord
        )
      end

      def model_class
        Spree::Store
      end
    end
  end
end
