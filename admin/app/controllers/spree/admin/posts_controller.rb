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

      def collection
        return @collection if @collection.present?

        @collection = super

        params[:q] ||= {}
        params[:q][:s] ||= 'published_at desc'

        @search = @collection.ransack(params[:q])
        @collection = @search.result.page(params[:page]).per(params[:per_page])
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
