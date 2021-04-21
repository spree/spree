module Spree
  module Api
    module V2
      class ResourceController < ::Spree::Api::V2::BaseController
        include Spree::Api::V2::CollectionOptionsHelpers

        def index
          render_serialized_payload { serialize_collection(paginated_collection) }
        end

        def show
          render_serialized_payload { serialize_resource(resource) }
        end

        protected

        def sorted_collection
          @sorted_collection ||= collection_sorter.new(collection, params, allowed_sort_attributes).call
        end

        def allowed_sort_attributes
          default_sort_atributes
        end

        def default_sort_atributes
          [:id, :name, :number, :updated_at, :created_at]
        end

        def scope
          model_class.accessible_by(current_ability, :show).includes(scope_includes)
        end

        def scope_includes
          []
        end

        def resource
          @resource ||= if defined?(resource_finder)
                          resource_finder.new(scope: scope, params: params).execute
                        else
                          scope.find(params[:id])
                        end
        end

        def collection
          @collection ||= if defined?(collection_finder)
                            collection_finder.new(scope: scope, params: params).execute
                          else
                            scope
                          end
        end

        def collection_sorter
          Spree::Api::Dependencies.storefront_collection_sorter.constantize
        end
      end
    end
  end
end
