module Spree
  module Api
    module V2
      module Caching
        extend ActiveSupport::Concern

        def collection_cache_key(collection)
          params.delete(:page) if params[:page] == 1

          cache_key_parts = [
            collection.cache_key_with_version,
            resource_includes,
            sparse_fields,
            serializer_params_cache_key,
            params[:sort]&.strip,
            params[:page]&.to_s&.strip,
            params[:per_page]&.to_s&.strip,
          ]
          cache_key_parts += additional_cache_key_parts if defined?(additional_cache_key_parts)
          cache_key_parts = cache_key_parts.flatten.join('-')

          Digest::MD5.hexdigest(cache_key_parts)
        end

        def collection_cache_opts
          {
            namespace: Spree::Api::Config[:api_v2_collection_cache_namespace],
            expires_in: Spree::Api::Config[:api_v2_collection_cache_ttl],
          }
        end

        def serializer_params_cache_key
          serializer_params.values.map do |param|
            param.try(:cache_key) || param.try(:flatten).try(:join, '-') || param.try(:to_s)
          end.compact.join('-')
        end
      end
    end
  end
end
