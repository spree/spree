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
      # This runs automatically in the ResourceController's `permitted_params` method,
      # eliminating boilerplate ID resolution and nested attribute transformation in
      # individual controllers and services.
      module ParamsNormalizer
        extend ActiveSupport::Concern

        protected

        # Override permitted_params to apply normalization after permitting
        def permitted_params
          normalize_params(super)
        end

        # Normalize params: resolve prefixed IDs and convert nested attributes
        def normalize_params(permitted)
          hash = permitted.to_h.with_indifferent_access
          hash = resolve_prefixed_ids(hash)
          hash = normalize_nested_attributes(hash)
          ActionController::Parameters.new(hash).permit!
        end

        private

        # Recursively resolve prefixed IDs in params.
        #
        # - Params ending in `_id` with string values matching prefix format → decoded to integer
        # - Params ending in `_ids` with array values → each element decoded
        # - Nested hashes and arrays of hashes are processed recursively
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

        # Convert flat nested arrays to Rails _attributes format.
        #
        # Uses the model's `nested_attributes_options` to detect which keys
        # should be renamed. For example, if Spree::Taxon has
        # `accepts_nested_attributes_for :taxon_rules`, then:
        #
        #   { taxon_rules: [{type: "...", value: "..."}] }
        #
        # becomes:
        #
        #   { taxon_rules_attributes: [{type: "...", value: "..."}] }
        def normalize_nested_attributes(hash)
          return hash unless model_class.respond_to?(:nested_attributes_options)

          nested_keys = model_class.nested_attributes_options.keys.map(&:to_s)
          return hash if nested_keys.empty?

          hash.each_with_object({}.with_indifferent_access) do |(key, value), result|
            key_str = key.to_s
            if nested_keys.include?(key_str) && !key_str.end_with?('_attributes')
              result["#{key_str}_attributes"] = value
            else
              result[key] = value
            end
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
