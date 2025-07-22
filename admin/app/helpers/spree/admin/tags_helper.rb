module Spree
  module Admin
    module TagsHelper
      def tags_scope
        @tags_scope ||= ActsAsTaggableOn::Tag.for_context(:tags)
      end

      def tags_json_array
        @tags_json_array ||= tags_scope.pluck(:id, :name).map { |id, name| { id: id, name: name } }.as_json
      end

      def post_tags_scope
        @post_tags_scope ||= ActsAsTaggableOn::Tag.
                             joins(:taggings).
                             where(ActsAsTaggableOn.taggings_table => { taggable_type: 'Spree::Post' }).
                             for_context(:tags).for_tenant(current_store.id)
      end

      def post_tags_json_array
        @post_tags_json_array ||= post_tags_scope.pluck(:id, :name).map { |id, name| { id: id, name: name } }.as_json
      end

      def user_tags_scope
        @user_tags_scope ||= ActsAsTaggableOn::Tag.
                             joins(:taggings).
                             where(ActsAsTaggableOn.taggings_table => { taggable_type: Spree.user_class.to_s }).
                             for_context(:tags)
      end

      def user_tags_json_array
        @user_tags_json_array ||= user_tags_scope.pluck(:id, :name).map { |id, name| { id: id, name: name } }.as_json
      end
    end
  end
end
