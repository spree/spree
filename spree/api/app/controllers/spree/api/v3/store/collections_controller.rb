module Spree
  module Api
    module V3
      module Store
        class CollectionsController < ResourceController
          include Spree::Api::V3::HttpCaching
          include Spree::Api::V3::Store::PermalinkLookup

          protected

          def model_class
            Spree::Collection
          end

          def serializer_class
            Spree.api.collection_serializer
          end

          # Only collections published on the request's channel, for list,
          # show and search alike: an unpublished collection is a 404.
          def scope
            super.published_on(Spree::Current.channel).ordered
          end

          def find_resource
            find_by_id_or_permalink!(scope, params[:id])
          end
        end
      end
    end
  end
end
