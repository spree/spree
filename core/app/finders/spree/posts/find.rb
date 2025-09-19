module Spree
  module Posts
    class Find < Spree::BaseFinder
      def initialize(scope:, params:)
        super(scope: scope, params: params)
        @scope = scope
        @query = params[:q].presence&.strip
        @ids = String(params.dig(:filter, :ids)).split(',')
        @slugs = String(params.dig(:filter, :slugs)).split(',')
        @category_ids = String(params.dig(:filter, :category_ids)).split(',')
        @author_ids = String(params.dig(:filter, :author_ids)).split(',')
        @tags = params.dig(:filter, :tags).to_s.split(',').compact_blank
        @sort_by = params[:sort_by]
        @published = params.dig(:filter, :published)
      end

      def execute
        posts = by_ids(scope)
        posts = by_slugs(posts)
        posts = by_query(posts)
        posts = by_category_ids(posts)
        posts = by_author_ids(posts)
        posts = by_tags(posts)
        posts = by_published(posts)
        posts = ordered(posts)

        posts.distinct
      end

      private

      attr_reader :scope, :query, :ids, :slugs, :category_ids, :author_ids, :tags, :sort_by, :published

      def query?
        query.present?
      end

      def ids?
        ids.present?
      end

      def slugs?
        slugs.present?
      end

      def category_ids?
        category_ids.present?
      end

      def author_ids?
        author_ids.present?
      end

      def tags?
        tags.present?
      end

      def published?
        published.present?
      end

      def sort_by?
        sort_by.present?
      end

      def by_query(posts)
        return posts unless query?

        posts.search_by_title(query)
      end

      def by_ids(posts)
        return posts unless ids?

        posts.where(id: ids)
      end

      def by_slugs(posts)
        return posts unless slugs?

        posts.where(slug: slugs)
      end

      def by_category_ids(posts)
        return posts unless category_ids?

        posts.where(post_category_id: category_ids)
      end

      def by_author_ids(posts)
        return posts unless author_ids?

        posts.where(author_id: author_ids)
      end

      def by_tags(posts)
        return posts if tags.empty?

        posts.tagged_with(tags, any: true)
      end

      def by_published(posts)
        return posts unless published?

        case published.to_s
        when 'true'
          posts.published
        when 'false'
          posts.where(published_at: nil)
        else
          posts
        end
      end

      def ordered(posts)
        return posts unless sort_by?

        case sort_by
        when 'newest-first'
          posts.by_newest
        when 'oldest-first'
          posts.order(created_at: :asc)
        when 'published-newest'
          posts.order(published_at: :desc)
        when 'published-oldest'
          posts.order(published_at: :asc)
        when 'title-a-z'
          posts.order(title: :asc)
        when 'title-z-a'
          posts.order(title: :desc)
        else
          posts
        end
      end
    end
  end
end