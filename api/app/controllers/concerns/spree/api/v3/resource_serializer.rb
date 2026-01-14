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
            includes: include_list
          }
        end

        # Parse include parameter into list
        # Supports: ?include=variants,images or ?include=variants.images
        def include_list
          return [] unless params[:include].present?

          params[:include].to_s.split(',').map(&:strip)
        end
      end
    end
  end
end
