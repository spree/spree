module Spree
  module Admin
    class PostCategoriesController < ResourceController
      add_breadcrumb Spree.t(:posts), :admin_posts_path
      add_breadcrumb Spree.t(:categories), :admin_post_categories_path

      private

      def permitted_resource_params
        params.require(:post_category).permit(permitted_post_category_attributes)
      end
    end
  end
end
