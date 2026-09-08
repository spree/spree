module Spree
  module Api
    module V3
      module Seller
        # What this seller packs their goods into: the boxes their parcels
        # ship in, the cartons their products are packed into, the pallets a
        # wholesale order leaves on (docs/plans/6.0-seller-package-types.md).
        #
        # The listing also carries the marketplace's own packaging, so a
        # seller can pack into the operator's standard cartons rather than
        # re-measuring them. Those rows are read-only: `find_resource` roots
        # writes in the seller's own packaging, so a marketplace row's id is a
        # 404 on every action but `show`.
        #
        # Marking a row default makes it the box this seller's parcels are
        # quoted with — one default per owner, so it never displaces the
        # marketplace's.
        class PackageTypesController < Seller::ResourceController
          scoped_resource :package_types

          protected

          def model_class
            Spree::PackageType
          end

          def serializer_class
            Spree.api.seller_package_type_serializer
          end

          # Reading shows the seller's own packaging plus the marketplace's —
          # the same set their variants may reference, so a carton picker can
          # ask "what can I pack into" rather than only "what have I
          # measured".
          #
          # `owner=mine` narrows it to the seller's own rows. The packaging
          # settings page asks for that, because a list mixing both owners
          # reads as "packaging is configured" while the seller has recorded
          # nothing — the shipping-box requirement then looks broken rather
          # than outstanding. Not a Ransack predicate: `available_to_seller`
          # composes with `.or()`, so a filter on `seller_id` widens back out
          # to the whole condition instead of narrowing it.
          def scope
            rows = current_store.package_types
            rows = params[:owner] == 'mine' ? rows.for_seller(current_seller) : rows.available_to_seller(current_seller)
            rows.preload_associations_lazily
          end

          # Writes root in the seller's own rows, so the marketplace's
          # packaging cannot be edited or deleted through this branch.
          def resource_scope
            current_seller.package_types
          end

          def find_resource
            action_name == 'show' ? super : resource_scope.find_by_prefix_id!(params[:id])
          end

          # No DISTINCT, so the owner ordering below is legal on PostgreSQL:
          # it rejects an ORDER BY expression that is not in the select list
          # of a SELECT DISTINCT, and `available_to_seller` makes the query
          # distinct through `.or()`. Nothing here needs it — one table, no
          # joins, so no row can appear twice.
          def collection_distinct?
            false
          end

          # The seller's own rows before the marketplace's, then by name.
          #
          # This list holds two owners' packaging, so it has roughly twice as
          # much to fit under the 100-row page limit as the operator's does.
          # Ordering here rather than in the client is what makes the limit
          # cut the shared rows instead of the seller's own measurements —
          # the page is taken before anything client-side can reorder it.
          # Ransack cannot express it: it drops the direction on `seller_id`,
          # and NULLs sort first ascending.
          #
          # Skipped when the caller asked for its own order.
          def apply_collection_sort(collection)
            return collection if params[:sort].present?

            collection.order(
              Arel.sql('CASE WHEN seller_id IS NULL THEN 1 ELSE 0 END'),
              Spree::PackageType.arel_table[:name].asc
            )
          end

          # The same set the operator's controller permits — a seller measures
          # their own packaging, so every field on the shared form is theirs
          # to set. `seller_id` is deliberately absent: ownership comes from
          # the authenticated seller, never the payload.
          def resource_permitted_attributes
            [:name, :kind, :length, :width, :height, :dimensions_unit,
             :weight, :max_weight, :weight_unit, :default, { metadata: {} }]
          end
        end
      end
    end
  end
end
