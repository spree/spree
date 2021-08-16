module Spree
  module Api
    module V2
      module Caching
        extend ActiveSupport::Concern

        def collection_cache_key(collection)
          unscoped_collection = collection.unscope(:includes).unscope(:order)
          cache_key_parts = [
            self.class.to_s,
            unscoped_collection.maximum(:updated_at),
            unscoped_collection.ids,
            resource_includes,
            sparse_fields,
            serializer_params,
            params[:sort]&.strip,
            params[:page]&.strip,
            params[:per_page]&.strip,
          ].flatten.join('-')

          Digest::MD5.hexdigest(cache_key_parts)
        end

        def collection_cache_opts
          {
            namespace: Spree::Api::Config[:api_v2_collection_cache_namespace],
            expires_in: Spree::Api::Config[:api_v2_collection_cache_ttl],
          }
        end
      end
    end
  end
end
