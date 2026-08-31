module Spree
  module Api
    module V3
      module Admin
        # The uniform nested products surface every product-curating parent
        # exposes — categories, collections, catalogs and price lists all
        # speak the same protocol:
        #
        #   GET    /{parents}/:parent_id/products                — paginated members
        #   POST   /{parents}/:parent_id/products                — { product_ids: [...] } → 201 { added_count }
        #   DELETE /{parents}/:parent_id/products                — { product_ids: [...] } → 200 { removed_count }
        #   PATCH  /{parents}/:parent_id/products/:id/reposition — positioned parents only
        #
        # Both writes are bulk: one request adds or removes any number of
        # products. Ids that don't resolve to a product in the current store
        # are silently dropped, already-present ids don't fail an add, and
        # non-member ids don't fail a remove — the counts report what actually
        # changed. Declared in routes through the +:product_membership+
        # routing concern.
        #
        # A host controller implements:
        #   +set_parent+              — load + authorize the parent record
        #   +scope+                   — the parent's member products
        #   +add_member_products+     — persist membership for the given products
        #   +remove_member_products+  — remove membership for the given products
        module ProductMembership
          extend ActiveSupport::Concern

          included do
            include Spree::Api::V3::Admin::ProductListing

            # Membership actions resolve products themselves; the base
            # single-resource load has nothing to look up.
            skip_before_action :set_resource
          end

          # POST /{parents}/:parent_id/products
          def create
            products = requested_products(product_scope)
            existing_ids = scope.where(id: products.map(&:id)).pluck(:id).to_set
            new_products = products.reject { |product| existing_ids.include?(product.id) }

            # Counted by re-reading membership rather than trusting the check
            # above: a concurrent request can claim one of these rows in
            # between, and the caller is told what actually changed.
            added = 0
            if new_products.any?
              add_member_products(new_products)
              added = scope.where(id: new_products.map(&:id)).reorder(nil).distinct.count
            end

            render json: { added_count: added }, status: :created
          end

          # DELETE /{parents}/:parent_id/products
          def destroy
            products = requested_products(scope)

            removed = 0
            if products.any?
              remove_member_products(products)
              # Counted from what is left, for the same reason as `create`.
              still_members = scope.where(id: products.map(&:id)).reorder(nil).distinct.count
              removed = products.size - still_members
            end

            render json: { removed_count: removed }
          end

          protected

          def model_class
            Spree::Product
          end

          def serializer_class
            Spree.api.admin_product_serializer
          end

          # @abstract Persist membership for products verified as new members.
          def add_member_products(_products)
            raise NotImplementedError
          end

          # @abstract Remove membership for products verified as members.
          def remove_member_products(_products)
            raise NotImplementedError
          end

          # Products the caller may act on, regardless of membership.
          def product_scope
            current_store.products.accessible_by(current_ability, :show)
          end

          private

          # Resolves the request's `product_ids` against the given relation.
          # Reordered: a positioned membership scope orders by a join-table
          # column, which PostgreSQL rejects under the DISTINCT needed here —
          # a derived scope (a price list's products through its price rows)
          # can join a product several times.
          def requested_products(relation)
            ids = decode_prefixed_ids(Array(params.require(:product_ids)))
            relation.reorder(nil).where(id: ids).distinct.to_a
          end
        end
      end
    end
  end
end
