module Spree
  module Api
    module V3
      module Store
        module Taxons
          class ProductsController < Store::ProductsController
            before_action :set_taxon

            protected

            def set_taxon
              @taxon = find_taxon
            end

            def scope
              Spree::Product.
                in_taxon(@taxon).
                for_store(current_store).
                accessible_by(current_ability, :show).
                available(Time.current, Spree::Current.currency).
                includes(scope_includes).
                preload_associations_lazily.
                i18n
            end

            private

            def find_taxon
              id = params[:taxon_id]
              taxon_scope = Spree::Taxon.for_store(current_store).accessible_by(current_ability, :show)
              taxon_scope = taxon_scope.i18n if Spree::Taxon.include?(Spree::TranslatableResource)

              if id.to_s.start_with?('txn_')
                taxon_scope.find_by_prefix_id!(id)
              else
                find_with_fallback_default_locale { taxon_scope.i18n.find_by!(permalink: id) }
              end
            end
          end
        end
      end
    end
  end
end
