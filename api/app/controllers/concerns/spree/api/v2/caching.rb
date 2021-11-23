module Spree
  module Api
    module V2
      module Caching
        extend ActiveSupport::Concern

        def collection_cache_key(collection)
          ids_and_timestamps = collection.unscope(:includes).unscope(:order).pluck(:id, :updated_at)

          ids = ids_and_timestamps.map(&:first)
          max_updated_at = ids_and_timestamps.map(&:last).max

          cache_key_parts = [
            self.class.to_s,
            max_updated_at,
            ids,
            resource_includes,
            sparse_fields,
            serializer_params,
            params[:sort]&.strip,
            params[:page]&.to_s&.strip,
            params[:per_page]&.to_s&.strip,
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
