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

          # PATCH /api/v3/admin/categories/:id/reposition
          # Body: { new_parent_id: 'ctg_…' (omit for top level), new_position: 0 }
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

          # Category-half attributes only. Deliberately excludes the
          # collection-bound fields (automatic, sort_order, rules_match_policy,
          # taxon_rules) and taxonomy_id — those belong to Spree::Collection
          # (6.0) and Taxonomy is being dropped. A prefixed parent_id resolves
          # within scope (so a parent from another store or an automatic taxon
          # can't be targeted).
          def permitted_params
            permitted = params.permit(
              :name, :description, :permalink,
              :meta_title, :meta_description, :meta_keywords,
              :hide_from_nav, :image, :square_image,
              # Inline custom field values keyed by definition id. The model
              # setter (Spree::Metafields#custom_fields=) validates each entry
              # against its definition. `value` is permitted as both a scalar
              # AND `value: {}` (any-shape Hash/Array) so JSON metafields can
              # ship parsed objects while text/number/boolean ship scalars.
              custom_fields: [:id, :custom_field_definition_id, :value, value: {}]
            )
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
          # awesome_nested_set's move_to_child_with_index(:root, ...) can't be
          # used here: its +roots+ are global (every parentless taxon across all
          # stores and taxonomies), whereas we order only this store's manual
          # roots (the +scope+). So position relative to the target root sibling.
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
