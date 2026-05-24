module Spree
  module Api
    module V3
      module Admin
        class TagsController < BaseController
          skip_scope_check!

          MAX_RESULTS = 50

          def index
            taggable_type = params[:taggable_type].to_s
            unless allowed_taggable_types.include?(taggable_type)
              render_error(
                code: 'invalid_taggable_type',
                message: "taggable_type must be one of #{allowed_taggable_types.join(', ')}",
                status: :unprocessable_content
              )
              return
            end

            scope = ActsAsTaggableOn::Tag.
                    joins(:taggings).
                    where(ActsAsTaggableOn.taggings_table => { taggable_type: taggable_type, context: 'tags' }).
                    distinct.
                    order(:name).
                    limit(MAX_RESULTS)

            if params[:q].present?
              # Escape LIKE wildcards in user input so a query like "foo_" matches
              # only the literal underscore, not any single character.
              escaped = params[:q].to_s.downcase.gsub(/[\\%_]/) { |c| "\\#{c}" }
              scope = scope.where('LOWER(name) LIKE ? ESCAPE ?', "%#{escaped}%", '\\')
            end

            render json: { data: scope.pluck(:name).map { |name| { name: name } } }
          end

          private

          # Sourced from `Spree.taggable_types` (registered in
          # `Spree::Core::Engine`'s after_initialize block). Apps extend the
          # list in an initializer without overriding this controller:
          #   Spree.taggable_types << 'MyApp::Vendor'
          def allowed_taggable_types
            Spree.taggable_types
          end
        end
      end
    end
  end
end
