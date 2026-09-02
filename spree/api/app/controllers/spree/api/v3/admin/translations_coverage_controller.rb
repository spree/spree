module Spree
  module Api
    module V3
      module Admin
        # Translation coverage across a whole resource type: per-locale totals
        # plus a paginated page of records carrying how many of their fields are
        # translated in each locale. Drives the centralized Translations page.
        #
        # Registry-driven like the rest of this surface — `resource_type` names
        # any member of Spree.translatable_resources, so a new translatable
        # model needs no code here.
        class TranslationsCoverageController < ResourceController
          # GET /api/v3/admin/translations?resource_type=product
          def index
            records = collection
            locales = translatable_locales

            render json: {
              data: {
                'resource_type' => Spree::Translations.public_resource_type(model_class),
                'default_locale' => current_store.default_locale,
                'locales' => locales,
                'field_count' => model_class.public_translatable_fields.size,
                'search_field' => search_field,
                'coverage' => Spree::Translations.coverage_for(scope, model_class, locales),
                'records' => serialize_records(records, locales)
              },
              meta: collection_meta(records)
            }
          end

          protected

          # Resolved from the required `resource_type` param. An unknown or
          # untranslatable type is a 404 rather than a 500 from a nil class.
          def model_class
            @model_class ||=
              Spree::Translations.resource_class(params[:resource_type]) ||
              raise(ActiveRecord::RecordNotFound, "Unknown translatable resource type: #{params[:resource_type]}")
          end

          # Reading a product's coverage needs `read_products`, a category's
          # `read_categories` — the same per-parent rule the per-resource
          # translations endpoint applies.
          def scoped_resource_name
            return :settings if params[:resource_type].blank?

            Spree::Translations.permission_resource_name(model_class)
          end

          # Store-scoped by the model itself, then ability-filtered the way the
          # admin base class does so a host app's record-level rules still bind.
          # Memoized: `index` reaches this for the paginated page and again for
          # the store-wide totals, and rebuilding it re-runs the ability filter
          # each time.
          def scope
            @scope ||= model_class.translatable_scope(current_store).
                       accessible_by(current_ability, ability_action_for_request)
          end

          # Coverage itself reads the translation tables in one grouped query,
          # so nothing needs eager-loading for it. The per-row label is a
          # different matter: it is normally answered from the record's own
          # column, but `always_use_translations` sends even the default locale
          # through the translation table, which without a preload is a query
          # per row.
          def collection_includes
            Spree.always_use_translations? ? [:translations] : []
          end

          # The grid sends a plain `search` term and lets the server choose the
          # predicate, since which one a model whitelists varies (`name` on
          # products and categories, nothing usable on collections).
          def ransack_params
            term = params[:search].presence
            field = search_field
            return super unless term && field

            super.to_h.merge(field => term)
          end

          private

          # The Ransack predicate the client may filter this grid by, or nil
          # when the model whitelists nothing usable. Reported rather than
          # assumed: `name` is ransackable on products and categories but not
          # on collections, and a client guessing `name_cont` either errors or
          # silently returns the unfiltered list.
          #
          # @return [String, nil]
          # The predicate the grid filters by. It has to match the column the
          # grid DISPLAYS, which is the record's first public translatable
          # field — for an option type that is `label`, stored as
          # `presentation`, while `name` holds a slug. Searching `name` there
          # means typing the visible label ("Shirt Size") returns nothing.
          #
          # Falls back to `name` when the displayed column is not ransackable,
          # since Ransack's defaults always carry it.
          #
          # @return [String, nil]
          def search_field
            return @search_field if defined?(@search_field)

            attributes = model_class.ransackable_attributes
            column = displayed_column
            field = [column, 'name'].compact.find { |candidate| attributes.include?(candidate) }
            @search_field = field && "#{field}_cont"
          end

          # The internal column behind the record's displayed label, resolving
          # any public-name alias (`label` -> `presentation`).
          #
          # @return [String, nil]
          def displayed_column
            public_field = model_class.public_translatable_fields.first
            return if public_field.nil?

            (model_class.translatable_field_aliases[public_field] || public_field).to_s
          end

          def translatable_locales
            Spree::Translations.non_default_locales(current_store)
          end

          # Each record carries its identifying label (whatever its first
          # translatable field is — `name` for most, `label` for option types)
          # read in the default locale, so the grid needs no second request.
          def serialize_records(records, locales)
            counts = Spree::Translations.translated_counts(records, model_class, locales)
            label_field = model_class.public_translatable_fields.first

            Mobility.with_locale(current_store.default_locale) do
              records.map do |record|
                {
                  'id' => record.prefixed_id,
                  'label' => record.public_send(label_field),
                  'locales' => locales.index_with { |locale| counts.dig(record.id, locale).to_i }
                }
              end
            end
          end

          def action_kind
            'read'
          end
        end
      end
    end
  end
end
