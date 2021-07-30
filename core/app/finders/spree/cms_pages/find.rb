module Spree
  module CmsPages
    class Find < ::Spree::BaseFinder
      ALLOWED_KINDS = %w[standard home feature].freeze

      def initialize(scope:, params:)
        @scope = scope
        @title = params.dig(:filter, :title)
        @kind  = params.dig(:filter, :type)
      end

      def execute
        pages = by_title(scope)
        pages = by_kind(pages)

        pages
      end

      private

      attr_reader :scope, :title, :kind

      def title_matcher
        Spree::CmsPage.arel_table[:title].matches("%#{title}%")
      end

      def by_title(pages)
        return pages if title.blank?

        pages.where(title_matcher)
      end

      def by_kind(pages)
        return pages if kind.blank?
        return pages if ALLOWED_KINDS.exclude?(kind)

        pages.send(kind)
      end
    end
  end
end
