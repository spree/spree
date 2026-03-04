module Spree
  module Api
    module V3
      module ResourceSerializer
        extend ActiveSupport::Concern

        protected

        # Serialize a single resource
        def serialize_resource(resource)
          serializer_class.new(resource, params: serializer_params).to_h
        end

        # Serialize a collection of resources
        def serialize_collection(collection)
          collection.map { |item| serializer_class.new(item, params: serializer_params).to_h }
        end

        # Params passed to serializers
        def serializer_params
          {
            currency: current_currency,
            store: current_store,
            user: current_user,
            locale: current_locale,
            expand: expand_list
          }
        end

        # Parse expand parameter into list
        # Supports: ?expand=variants,images
        def expand_list
          expand_param = params[:expand].presence
          return [] unless expand_param

          expand_param.to_s.split(',').map(&:strip)
        end
      end
    end
  end
end
