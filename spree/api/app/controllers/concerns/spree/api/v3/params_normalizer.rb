module Spree
  module Api
    module V3
      # Normalizes flat API v3 JSON params for Rails model consumption:
      #
      # 1. **Prefixed ID resolution** — decodes Stripe-style prefixed IDs (e.g. "prod_86Rf07xd4z")
      #    to integer primary keys for any param ending in `_id` or `_ids`.
      #
      # 2. **Nested attributes normalization** — converts flat arrays (e.g. `taxon_rules: [...]`)
      #    to Rails `_attributes` format (e.g. `taxon_rules_attributes: [...]`) based on
      #    the model's `accepts_nested_attributes_for` declarations.
      #
      # Uses `prepend` so it always wraps `permitted_params` regardless of which
      # controller in the hierarchy defines it — no manual calls needed.
      module ParamsNormalizer
        extend ActiveSupport::Concern

        private

        def normalize_params(permitted)
          hash = permitted.to_h.with_indifferent_access
          hash = resolve_prefixed_ids(hash)
          hash = normalize_nested_attributes(hash)
          ActionController::Parameters.new(hash).permit!
        end

        def resolve_prefixed_ids(hash)
          hash.each_with_object({}.with_indifferent_access) do |(key, value), result|
            result[key] = case
                          when key.to_s.end_with?('_id') && prefixed_id?(value)
                            decode_prefixed_id(value)
                          when key.to_s.end_with?('_ids') && value.is_a?(Array)
                            value.map { |v| prefixed_id?(v) ? decode_prefixed_id(v) : v }
                          when value.is_a?(Hash)
                            resolve_prefixed_ids(value)
                          when value.is_a?(Array)
                            value.map { |v| v.is_a?(Hash) ? resolve_prefixed_ids(v) : v }
                          else
                            value
                          end
          end
        end

        def normalize_nested_attributes(hash, klass = model_class)
          return hash unless klass.respond_to?(:nested_attributes_options)

          nested_keys = klass.nested_attributes_options.keys.map(&:to_s)
          return hash if nested_keys.empty?

          hash.each_with_object({}.with_indifferent_access) do |(key, value), result|
            key_str = key.to_s
            if nested_keys.include?(key_str) && !key_str.end_with?('_attributes')
              child_class = klass.reflect_on_association(key_str)&.klass
              result["#{key_str}_attributes"] = normalize_nested_values(value, child_class)
            else
              result[key] = value
            end
          end
        end

        def normalize_nested_values(value, child_class)
          return value unless child_class

          case value
          when Array
            value.map { |v| v.is_a?(Hash) ? normalize_nested_attributes(v.with_indifferent_access, child_class) : v }
          when Hash
            normalize_nested_attributes(value.with_indifferent_access, child_class)
          else
            value
          end
        end

        def prefixed_id?(value)
          Spree::PrefixedId.prefixed_id?(value)
        end

        def decode_prefixed_id(prefixed_id_string)
          Spree::PrefixedId.decode_prefixed_id(prefixed_id_string) || prefixed_id_string
        end
      end
    end
  end
end
