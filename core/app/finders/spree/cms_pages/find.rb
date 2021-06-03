module Spree
  module CmsPage
    class Find < ::Spree::BaseFinder
      def initialize(scope:, params:)
        @scope = scope
        @title  = params.dig(:filter, :title)
      end

      def execute
        pages = by_title(pages)

        pages
      end

      def title_matcher
        Spree::CmsPage.arel_table[:title].matches("%#{title}%")
      end

      def by_title(pages)
        pages.where(title_matcher)
      end
    end
  end
end
