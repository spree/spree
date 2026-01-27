module Spree
  module Api
    module V2
      module PublicMetafieldsConcern
        extend ActiveSupport::Concern

        included do
          has_many :metafields, serializer: Spree.api.storefront_metafield_serializer,
                                record_type: :metafield,
                                object_method_name: :public_metafields
        end
      end
    end
  end
end