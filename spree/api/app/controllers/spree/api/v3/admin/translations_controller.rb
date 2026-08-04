module Spree
  module Api
    module V3
      module Admin
        # Read-only translation matrix for any parent in the
        # +Spree.translatable_resources+ registry. Mounted via the
        # +:translatable+ route concern; the parent class is inferred from
        # whichever +<segment>_id+ route param matches a registered translatable
        # resource. One controller serves every model.
        #
        # Writes go through the batch endpoint (+POST /admin/translations/batch+)
        # — a single atomic surface that also handles multi-record saves (an
        # option type plus all its option values). There is no per-resource
        # write here.
        class TranslationsController < ResourceController
          # This controller acts on the @parent (set by set_parent), never on a
          # @resource of its own, so the base set_resource lookup (which needs a
          # model_class) must not run.
          skip_before_action :set_resource
          before_action :ensure_translatable!

          # GET /api/v3/admin/<parent>/<parent_id>/translations
          # Returns the matrix + discovery fields, with nested translatable
          # children (e.g. an option type's values) so an editor fetches the
          # whole tree in one read.
          def index
            render json: { data: serialize_translations(@parent) }
          end

          protected

          def set_parent
            raise ActiveRecord::RecordNotFound, 'Parent resource not found' unless parent_lookup

            @parent = parent_relation.find_by_prefix_id!(parent_lookup.value)
            authorize!(:show, @parent)
          end

          # Resolves the parent within the current store so a token for one
          # store can't read or write another store's translations. Preloads
          # translatable children + their translation rows so the nested matrix
          # read (e.g. an option type's values) avoids an N+1 over the child
          # translation tables.
          def parent_relation
            klass = parent_lookup.klass
            relation = klass.respond_to?(:for_store) ? klass.for_store(current_store) : klass

            children = klass.try(:translatable_children)
            children ? relation.includes(children => :translations) : relation
          end

          # Per-parent scope check: reading a product's translations needs
          # `read_products`, a category's `read_categories`, etc.
          def scoped_resource_name
            parent_lookup&.segment&.pluralize&.to_sym
          end

          # Translatable by class hierarchy, not strict equality, so a subclass
          # instance (e.g. Spree::Category < Spree::Category) passes when its base
          # is registered.
          def ensure_translatable!
            # Compare by class NAME, not object identity: in dev the registry is
            # populated at boot, but the model constants are reloaded on edits,
            # so `is_a?(registered_class)` fails against a stale class object even
            # when @parent's live class (or an ancestor) matches by name. Walk the
            # ancestor names so a subclass (Spree::Category < Spree::Category) passes.
            registered = Spree.translatable_resources.map(&:name).to_set
            translatable = @parent.class.ancestors.any? { |ancestor| registered.include?(ancestor.name) }
            raise ActiveRecord::RecordNotFound unless translatable
          end

          ParentLookup = Struct.new(:klass, :value, :segment)

          # Maps route segment ('product', 'category', …) to model class name.
          # Class names (not objects) survive dev-mode reloads. Aliases
          # 'category' because routes expose taxons as categories (5.5 rename)
          # while the model element is still 'taxon'.
          def parent_route_map
            @parent_route_map ||= Spree.translatable_resources.each_with_object({}) do |klass, m|
              m[klass.model_name.element.to_s] = klass.name
            end.merge('category' => 'Spree::Category')
          end

          def parent_lookup
            return @parent_lookup if defined?(@parent_lookup)

            match = parent_route_map.find { |segment, _| params[:"#{segment}_id"].present? }
            @parent_lookup =
              if match
                segment, klass_name = match
                ParentLookup.new(klass_name.constantize, params[:"#{segment}_id"], segment)
              end
          end

          # Full read shape: matrix + discovery fields + nested children +
          # the locale envelope.
          def serialize_translations(record)
            Spree.api.admin_resource_translations_serializer.new(
              record, params: serializer_params.merge(fields: true, envelope: true)
            ).to_h
          end
        end
      end
    end
  end
end
