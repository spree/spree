module Spree
  module Api
    module V3
      module Store
        class TaxonsController < ResourceController
          protected

          def model_class
            Spree::Taxon
          end

          def serializer_class
            Spree.api.taxon_serializer
          end

          # Find taxon by permalink or prefix_id with i18n scope for SEO-friendly URLs
          # Falls back to default locale if taxon is not found in the current locale
          def find_resource
            id = params[:id]
            if id.to_s.start_with?('txn_')
              scope.find_by!(prefix_id: id)
            else
              find_with_fallback_default_locale { scope.i18n.find_by!(permalink: id) }
            end
          end

          def collection_includes
            [:taxonomy]
          end
        end
      end
    end
  end
end
