module Spree
  module Admin
    class PostCategoriesController < ResourceController
      include Spree::Admin::TableConcern

      add_breadcrumb Spree.t(:posts), :admin_posts_path
      add_breadcrumb Spree.t(:categories), :admin_post_categories_path

      def select_options
        post_categories = current_store.post_categories.accessible_by(current_ability)
        render json: post_categories.pluck(:id, :title).map { |id, title| { id: id, name: title } }
      end

      private

      def permitted_resource_params
        params.require(:post_category).permit(permitted_post_category_attributes)
      end
    end
  end
end
