module Spree
  module UserSegmentHelper
    def identyfy_user
      render_serialized_payload { serialize_resource(resource)[:data][:attributes] }
    end

    private

    def resource
      try_spree_current_user
    end

    def resource_serializer
      Spree::Api::Dependencies.storefront_user_segment_serializer.constantize
    end
  end
end
