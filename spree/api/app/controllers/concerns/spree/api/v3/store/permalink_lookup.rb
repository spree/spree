module Spree
  module Api
    module V3
      module Store
        # Finds a category or collection by prefixed id, current permalink
        # (in the request's locale, then the store's default one) or a
        # permalink it used before a rename. The response carries the current
        # permalink, so a storefront compares it and redirects.
        module PermalinkLookup
          extend ActiveSupport::Concern

          private

          def find_by_id_or_permalink!(records, id)
            return records.find_by_prefix_id!(id) if records.decode_own_prefixed_id(id.to_s)

            find_with_fallback_default_locale { records.i18n.find_by!(permalink: id) }
          rescue ActiveRecord::RecordNotFound
            records.find_from_permalink_history!(id)
          end
        end
      end
    end
  end
end
