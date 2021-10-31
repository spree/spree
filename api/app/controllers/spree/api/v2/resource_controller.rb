module Spree
  module Api
    module V2
      class ResourceController < ::Spree::Api::V2::BaseController
        include Spree::Api::V2::CollectionOptionsHelpers
        include Spree::Api::V2::Caching

        def index
          render_serialized_payload do
            Rails.cache.fetch(collection_cache_key(paginated_collection), collection_cache_opts) do
              serialize_collection(paginated_collection)
            end
          end
        end

        def show
          render_serialized_payload { serialize_resource(resource) }
        end

        protected

        def sorted_collection
          @sorted_collection ||= collection_sorter.new(collection, params, allowed_sort_attributes).call
        end

        def allowed_sort_attributes
          default_sort_attributes
        end

        def default_sort_attributes
          [:id, :name, :slug, :number, :position, :updated_at, :created_at, :deleted_at]
        end

        def scope(skip_cancancan: false)
          base_scope = model_class.for_store(current_store)
          base_scope = base_scope.accessible_by(current_ability, :show) unless skip_cancancan
          base_scope = base_scope.includes(scope_includes) if scope_includes.any? && action_name == 'index'
          base_scope
        end

        def scope_includes
          []
        end

        def resource
          @resource ||= if defined?(resource_finder)
                          resource_finder.new(scope: scope, params: finder_params).execute
                        else
                          scope.find(params[:id])
                        end
        end

        def collection
          @collection ||= if defined?(collection_finder)
                            collection_finder.new(scope: scope, params: finder_params).execute
                          else
                            scope
                          end
        end

        def finder_params
          params.merge(
            store: current_store,
            locale: current_locale,
            currency: current_currency,
            user: spree_current_user
          )
        end

        def collection_sorter
          Spree::Api::Dependencies.storefront_collection_sorter.constantize
        end
      end
    end
  end
end
