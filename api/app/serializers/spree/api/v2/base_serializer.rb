module Spree
  module Api
    module V2
      class BaseSerializer
        include JSONAPI::Serializer

        # to learn more about caching, please refer to:
        # https://github.com/jsonapi-serializer/jsonapi-serializer#caching
        # https://guides.rubyonrails.org/caching_with_rails.html#low-level-caching
        cache_options(store: Rails.cache, namespace: 'jsonapi-serializer', expires_in: Spree::Api::Config[:api_v2_serializers_cache_ttl])

        def self.record_cache_options(options, fieldset, include_list, params)
          opts = options.dup

          params_cache_key = params.map do |param|
            next if param.nil? || param.last.nil?

            if param.last.respond_to?(:cache_key_with_version)
              param.last.cache_key_with_version
            else
              param.last.to_s.downcase
            end
          end.compact.reject(&:blank?).join('-')

          opts[:namespace] += "-#{params_cache_key}"

          super(opts, fieldset, include_list, params)
        end
      end
    end
  end
end
