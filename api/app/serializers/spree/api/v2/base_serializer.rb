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
            value = param.last
            next if param.nil? || value.nil?

            if value.respond_to?(:cache_key_with_version)
              value.cache_key_with_version
            elsif value.is_a?(Hash)
              # covers the current_price_options cases:
              #     { price_options: { tax_zone: Spree::Zone... } } or
              #     { price_options: { tax_zone: nil } }
              only_key = value.keys.first
              value[only_key]&.cache_key_with_version
            else
              value.to_s.downcase
            end
          end.compact.reject(&:blank?).join('-')

          opts[:namespace] += "-#{params_cache_key}"

          super(opts, fieldset, include_list, params)
        end
      end
    end
  end
end
