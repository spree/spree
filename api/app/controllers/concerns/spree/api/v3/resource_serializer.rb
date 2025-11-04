module Spree
  module Api
    module V3
      module ResourceSerializer
        extend ActiveSupport::Concern

        protected

        # Serialize a single resource
        def serialize_resource(resource)
          serializer_class.new(resource, serializer_context).as_json
        end

        # Serialize a collection of resources
        def serialize_collection(collection)
          collection.map { |item| serializer_class.new(item, serializer_context).as_json }
        end
      end
    end
  end
end
