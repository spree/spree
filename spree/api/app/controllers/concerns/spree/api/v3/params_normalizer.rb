module Spree
  module Api
    module V3
      # Normalizes flat API v3 JSON params for Rails model consumption:
      #
      # 1. **Prefixed ID resolution** — decodes Stripe-style prefixed IDs (e.g. "prod_86Rf07xd4z")
      #    to integer primary keys for any param ending in `_id` or `_ids`.
      #
      # 2. **Nested attributes normalization** — converts flat arrays (e.g. `variants: [...]`)
      #    to Rails `_attributes` format (e.g. `variants_attributes: [...]`) based on
      #    the model's `accepts_nested_attributes_for` declarations.
      #
      # `normalize_params` is called explicitly by a controller's
      # `permitted_params`. It is deliberately NOT applied to every write: it
      # recurses into nested hashes decoding anything shaped like a prefixed ID,
      # which would corrupt opaque provider values (see
      # Admin::PaymentMethodsController).
      module ParamsNormalizer
        extend ActiveSupport::Concern

        private

        def normalize_params(permitted)
          hash = permitted.to_h.with_indifferent_access
          hash = resolve_prefixed_ids(hash)
          hash = normalize_nested_attributes(hash)
          ActionController::Parameters.new(hash).permit!
        end

        # @param owner [Class, nil] the model whose associations name these
        #   keys, so `variant_id` is checked against `Spree::Variant`
        def resolve_prefixed_ids(hash, owner = (model_class if respond_to?(:model_class, true)))
          hash.each_with_object({}.with_indifferent_access) do |(key, value), result|
            result[key] = case
                          # Preferences declare which of their values are ids
                          # and decode only those, after checking them against
                          # their schema.
                          when key.to_s == 'preferences'
                            value
                          when key.to_s.end_with?('_id') && prefixed_id?(value)
                            decode_prefixed_id(value, key, owner)
                          when key.to_s.end_with?('_ids') && value.is_a?(Array)
                            value.map { |v| prefixed_id?(v) ? decode_prefixed_id(v, key, owner) : v }
                          when value.is_a?(Hash)
                            resolve_prefixed_ids(value, nested_owner(key, owner))
                          when value.is_a?(Array)
                            nested = nested_owner(key, owner)
                            value.map { |v| v.is_a?(Hash) ? resolve_prefixed_ids(v, nested) : v }
                          else
                            value
                          end
          end
        end

        # The model a nested hash or array of hashes describes, so the keys
        # inside it are checked against the right associations: an order's
        # `items` are line items, whose `variant_id` is a variant.
        #
        # A payload name is a public contract and does not always match the
        # association — `items` is `line_items` — so a controller whose
        # names differ declares the mapping in {nested_param_models}.
        def nested_owner(key, owner)
          return if owner.nil?

          declared = nested_param_models[key.to_s]
          return declared if declared

          name = key.to_s
          reflection = owner.try(:reflect_on_association, name) ||
                       owner.try(:reflect_on_association, name.singularize)
          reflection&.klass
        rescue StandardError
          nil
        end

        # Payload key => the model its rows describe, for the keys that do not
        # name an association of their own.
        #
        # @return [Hash{String => Class}]
        def nested_param_models
          {}
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

        # A prefixed id is decoded only when its prefix is the one the column
        # expects. The sqid alphabet is shared, so `prod_` and `variant_`
        # decode to the same integers: without this an order asked for a
        # product answered 201 and held a line item for whatever variant
        # happened to carry that number.
        #
        # An id of the wrong kind is left as it was. The association then
        # fails to find it, which is a 404 or a validation error naming the
        # field — the same answer any other unknown id gets, rather than a
        # quiet write of the wrong record.
        def decode_prefixed_id(prefixed_id_string, key = nil, owner = nil)
          target = association_class(key, owner)

          decoded = if target.respond_to?(:decode_own_prefixed_id)
                      target.decode_own_prefixed_id(prefixed_id_string)
                    else
                      Spree::PrefixedId.decode_prefixed_id(prefixed_id_string)
                    end

          decoded || prefixed_id_string
        end

        # What `variant_id` points at, read from the owner's own association
        # rather than guessed from the name — `reason_id` is a different class
        # on a cancellation than on a refund.
        def association_class(key, owner)
          return if key.nil? || owner.nil?

          name = key.to_s.sub(/_ids?\z/, '')
          # `category_ids` names `has_many :categories`, so the singular form
          # finds nothing and the id went through unchecked — the same hole
          # the singular `_id` case had.
          reflection = owner.try(:reflect_on_association, name) ||
                       owner.try(:reflect_on_association, name.pluralize)
          return if reflection.nil? || reflection.polymorphic?

          reflection.klass
        rescue StandardError
          nil
        end
      end
    end
  end
end
