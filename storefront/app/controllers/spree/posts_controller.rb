module Spree
  class PostsController < Spree::StoreController
    before_action :load_category, if: -> { params[:category_id].present? }, only: :index
    before_action :load_tag, if: -> { params[:tag].present? }, only: :index

    after_action :track_show, only: :show

    def index
      @current_page = current_theme.pages.find_by!(type: 'Spree::Pages::PostList')

      scope = current_store.posts.published
      scope = scope.tagged_with(@tag.name) if @tag.present?
      scope = scope.where(post_category_id: @category.id) if @category.present?

      sorted_posts = scope.order(published_at: :desc)
      @posts = sorted_posts.page(params[:page]).per(20)
    end

    def show
      if params[:preview_id].present?
        preview_post = current_store.posts.friendly.find(params[:id])
        raise ActiveRecord::RecordNotFound if preview_post.id.to_s != params[:preview_id]

        @post ||= preview_post
      else
        @post = current_store.posts.friendly.published.find(params[:id])
      end

      @current_page = current_theme.pages.find_by!(type: 'Spree::Pages::Post')
    end

    def related_products
      @post = Spree::Post.friendly.find(params[:id])
      current_page = current_theme.pages.find_by!(type: 'Spree::Pages::Post')
      @section = current_page.sections.find_by!(id: params[:section_id], type: 'Spree::PageSections::RelatedProducts')
    end

    private

    def accurate_title
      if @post
        @post.meta_title.presence || @post.title
      elsif @category.present? && @tag.present?
        "#{@category.title} / #{@tag.name.titleize}"
      elsif @category.present?
        @category.title
      elsif @tag.present?
        Spree.t(:all_posts_with_tag, tag: @tag.name.titleize)
      else
        Spree.t(:all_posts)
      end
    end

    def load_category
      @category = current_store.post_categories.friendly.find(params[:category_id])
      @page_description = @category.description.to_plain_text
    end

    def load_tag
      @tag = post_tags_scope.find_by!(name: params[:tag].strip)
    end

    def post_tags_scope
      @post_tags_scope ||= ActsAsTaggableOn::Tag.
                           joins(:taggings).
                           where('taggings.taggable_type = ?', Spree::Post.to_s).
                           for_context(:tags).for_tenant(current_store.id)
    end

    def track_show
      return if turbo_frame_request? || turbo_stream_request?

      track_event('post_viewed', { post_id: @post.id })
    end
  end
end
