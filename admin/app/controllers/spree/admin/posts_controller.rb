module Spree
  module Admin
    class PostsController < ResourceController
      before_action :load_post_categories

      include StorefrontBreadcrumbConcern
      add_breadcrumb Spree.t(:posts), :admin_posts_path

      before_action :add_breadcrumb_for_post, only: [:edit, :update]

      def select_options
        render json: current_store.posts.published.to_tom_select_json
      end

      private

      def collection_includes
        [:author, :post_category, :image_attachment]
      end

      def load_post_categories
        @post_categories = current_store.post_categories.accessible_by(current_ability).order(:title)
      end

      def add_breadcrumb_for_post
        return unless @post.present?

        add_breadcrumb @post.title, spree.edit_admin_post_path(@post)
      end

      def permitted_resource_params
        params.require(:post).permit(permitted_post_attributes)
      end
    end
  end
end
