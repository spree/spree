module Spree
  module Api
    module V2
      module PublicMetafieldsConcern
        extend ActiveSupport::Concern

        included do
          has_many :metafields, serializer: Spree::Api::Dependencies.storefront_metafield_serializer.constantize,
                                record_type: :metafield,
                                object_method_name: :public_metafields
        end
      end
    end
  end
end