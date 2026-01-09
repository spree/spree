module Spree
  module Admin
    class TagsController < Spree::Admin::BaseController
      def select_options
        tags = tags_scope

        if params[:q].present?
          tags = tags.where('LOWER(name) LIKE ?', "%#{params[:q].downcase}%")
        end

        render json: tags.limit(100).pluck(:id, :name).map { |id, name| { id: id, name: name } }
      end

      private

      def tags_scope
        context = params[:context].presence || 'tags'
        taggable_type = params[:taggable_type].presence

        scope = Spree::Tag.for_context(context)

        if taggable_type.present?
          scope = scope.joins(:taggings)
                       .where(Spree::Tagging.table_name => { taggable_type: taggable_type })
                       .distinct
        end

        scope.order(:name)
      end
    end
  end
end
