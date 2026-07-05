module Spree
  module Api
    module V3
      module Store
        module SearchProviderSupport
          extend ActiveSupport::Concern

          # Matches `*_id_in`/`id_eq`/etc. and the bare `id_in`/`id_eq` on
          # the resource's primary key. Mirrors the regex on
          # `ResourceController` — duplicated here because `FiltersController`
          # extends `Store::BaseController`, not `ResourceController`, and
          # would otherwise NoMethodError on `decode_prefixed_id_predicates`.
          # Requires a Ransack-predicate suffix so we don't match scope
          # names like `with_option_value_ids` (which handle their own
          # prefix decoding).
          RANSACK_ID_PREDICATE_RE = /(?:\A|_)id(?:s)?_(?:eq|not_eq|in|not_in|lt|lteq|gt|gteq)\z/.freeze

          private

          def search_query
            params.dig(:q, :search)
          end

          def search_filters
            q = params[:q]&.to_unsafe_h || params[:q] || {}
            q = q.to_h if q.respond_to?(:to_h) && !q.is_a?(Hash)
            # Decode Stripe-style prefixed IDs in `*_id_in`/`id_eq`/etc. so
            # SPA + storefront filters can pass `prod_…` keys; the search
            # provider hands the filter hash straight to Ransack on the
            # underlying scope, which expects raw integer IDs.
            decode_prefixed_id_predicates(q.except('search')).presence
          end

          def search_provider
            @search_provider ||= Spree.search_provider.constantize.new(current_store)
          end

          def decode_prefixed_id_predicates(hash)
            return hash unless hash.is_a?(Hash)

            hash.each_with_object({}) do |(key, value), result|
              result[key] = if ransack_id_predicate?(key)
                              Array(value).map { |v| Spree::PrefixedId.prefixed_id?(v) ? Spree::PrefixedId.decode_prefixed_id(v) || v : v }.then { |arr|
                                value.is_a?(Array) ? arr : arr.first
                              }
                            elsif value.is_a?(Hash)
                              decode_prefixed_id_predicates(value)
                            else
                              value
                            end
            end
          end

          def ransack_id_predicate?(key)
            RANSACK_ID_PREDICATE_RE.match?(key.to_s)
          end
        end
      end
    end
  end
end
