module Spree
  module Api
    module V3
      module Admin
        # Admin CRUD for categories — the hierarchical product classification
        # half of today's dual-purpose Taxon. Rule-based / automatic taxons
        # (the "collection" half moving to Spree::Collection in 6.0) are
        # excluded from this API entirely (see +scope+), and none of the
        # collection-bound attributes (automatic, sort_order, rules) are
        # readable or writable here.
        class CategoriesController < ResourceController
          scoped_resource :categories

          # Category-half attributes only. The collection-bound fields
          # (automatic, sort_order, rules) belong to Spree::Collection, and
          # taxonomy_id is gone with Taxonomy.
          request_params :category do |body|
            body.external_references
            body.attribute :name, :string, required: true, on: :create, example: 'Shirts'
            # Resolved within scope by +permitted_params+, so a parent from
            # another store or an automatic taxon can't be targeted.
            body.attribute :parent_id, :id,
              nullable: true,
              permit: false,
              example: 'ctg_abc123',
              description: 'The parent category. Omitted or null, a new category goes to the top level and an existing one keeps its parent: moving one to the top level is the reposition endpoint.'
            body.attribute :description, :string,
              description: 'Rich text HTML. Reads come back as this (plain text) plus `description_html`.'
            body.attribute :permalink, :string
            body.attribute :meta_title, :string
            body.attribute :meta_description, :string
            body.attribute :meta_keywords, :string
            body.attribute :image_signed_id, :string,
              nullable: true,
              description: 'A `signed_id` from `files.upload()` for the landscape image, or null to remove it.'
            body.attribute :square_image_signed_id, :string,
              nullable: true,
              description: 'A `signed_id` from `files.upload()` for the square image, or null to remove it.'
            body.attribute :custom_fields, :array, of: Spree::Api::V3::CustomFieldValueRequestSchema,
              description: 'Custom field values, each validated against its definition.'
          end

          request_params 'CategoryRepositionParams', action: :reposition do |body|
            body.attribute :new_parent_id, :id,
              nullable: true,
              description: 'The new parent. Omit or null to move the category to the top level.'
            body.attribute :new_position, :integer,
              required: true,
              example: 0,
              description: "0-based index among the new parent's children."
          end

          # PATCH /api/v3/admin/categories/:id/reposition
          # Moves the category to a new parent (or the top level) and/or index.
          def reposition
            category = find_resource
            authorize! :update, category

            position = integer_param(:new_position)
            return render_invalid_position if position.nil?

            # Operate on a base Taxon instance (unscoped): the Category default
            # i18n scope interferes with awesome_nested_set's lft/rgt reads, so
            # the move silently no-ops on a scoped instance.
            node = scope.find(category.id)
            parent = reposition_parent

            if parent
              # move_to_child_with_index positions among the parent's children.
              node.move_to_child_with_index(scope.find(parent.id), reposition_index(category, position, siblings_of(parent)))
            else
              move_to_root_at_index(node, reposition_index(category, position, siblings_of(nil)))
            end
            render json: serialize_resource(category.reload)
          rescue CollectiveIdea::Acts::NestedSet::Move::ImpossibleMove => e
            render_error(
              code: ERROR_CODES[:validation_error],
              message: e.message,
              status: :unprocessable_content
            )
          end

          protected

          def model_class
            Spree::Category
          end

          def serializer_class
            Spree.api.admin_category_serializer
          end

          # Categories exclude automatic (rule-based) rows, which still live in
          # spree_categories until the Phase 4 migration moves them to Collections.
          # No-op after migration; the .manual scope is removed in 6.1.
          def scope
            super.manual
          end

          def permitted_params
            permitted = params.permit(*permitted_attributes)
            permitted[:parent] = scope.find_by_prefix_id!(params[:parent_id]) if params[:parent_id].present?
            permitted
          end

          private

          # Target parent for a reposition — the requested category, or nil to
          # promote to the top level.
          # @return [Spree::Category, nil]
          def reposition_parent
            scope.find_by_prefix_id!(params[:new_parent_id]) if params[:new_parent_id].present?
          end

          # The siblings among which the node is being placed, in tree order:
          # the parent's children, or the store's root categories at the top
          # level.
          # @return [ActiveRecord::Relation]
          def siblings_of(parent)
            parent ? parent.children : scope.where(parent_id: nil).order(:lft)
          end

          # Clamp the requested 0-based index into the valid range so an
          # out-of-range index appends to the end instead of dereferencing a nil
          # sibling. The category can occupy indices 0..N where N is the count of
          # its *other* siblings; index N places it last.
          # @return [Integer]
          def reposition_index(category, position, siblings)
            others = siblings.where.not(id: category.id).count
            position.clamp(0, others)
          end

          # Positions the node at +index+ among the store's root categories.
          # Deliberately not move_to_child_with_index(:root, ...): that indexes
          # into awesome_nested_set's class-level +roots+, which stays global
          # across stores even though the set is scoped per store. Positioning
          # relative to the target sibling keeps the index meaning what the
          # caller computed it from — this store's roots.
          def move_to_root_at_index(node, index)
            others = scope.where(parent_id: nil).where.not(id: node.id).order(:lft).to_a
            target = others[index]
            if target
              node.move_to_left_of(target)
            elsif others.any?
              node.move_to_right_of(others.last)
            else
              node.move_to_root
            end
          end
        end
      end
    end
  end
end
