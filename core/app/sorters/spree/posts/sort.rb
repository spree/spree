module Spree
  module Posts
    class Sort < ::Spree::BaseSorter
      def initialize(scope, params = {}, allowed_sort_attributes = [])
        super(scope, params, allowed_sort_attributes)
      end

      def call
        posts = by_param_attributes(scope)
        posts = select_translatable_fields(posts) if Spree.use_translations?

        posts.distinct
      end

      private

      attr_reader :sort, :scope, :allowed_sort_attributes

      # Add translatable fields to SELECT statement to avoid InvalidColumnReference error (workaround for Mobility issue #596)
      def select_translatable_fields(scope)
        translatable_fields = translatable_sortable_fields
        return scope if translatable_fields.empty?

        scope.i18n.select("#{Post.table_name}.*").select(*translatable_fields)
      end

      def translatable_sortable_fields
        fields = []
        Post.translatable_fields.each do |field|
          fields << field if sort_by?(field.to_s)
        end
        fields
      end

      def sort_by?(field)
        sort.detect { |s| s[0] == field }
      end
    end
  end
end