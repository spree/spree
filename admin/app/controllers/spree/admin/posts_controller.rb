module Spree
  module Admin
    class PostsController < ResourceController
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
    end
  end
end
