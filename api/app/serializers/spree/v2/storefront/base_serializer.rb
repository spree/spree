require 'active_support/cache'

module Spree
  module V2
    module Storefront
      class BaseSerializer
        include JSONAPI::Serializer

        cache_options(store: Rails.cache, namespace: 'jsonapi-serializer', expires_in: Spree::Api::Config[:api_v2_cache_ttl])

        def self.record_cache_options(options, fieldset, include_list, params)
          opts = options.dup

          params_cache_key = [params[:currency], params[:user]&.cache_key, params[:store]&.cache_key].join('-')

          opts[:namespace] += "-#{params_cache_key}"

          super(opts, fieldset, include_list, params)
        end
      end
    end
  end
end
