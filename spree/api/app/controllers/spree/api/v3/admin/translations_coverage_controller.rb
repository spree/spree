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
                'field_count' => Spree::Translations.field_count(model_class),
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

            Spree.permissions.resource_for_subject(model_class)&.name ||
              Spree::Translations.public_resource_type(model_class).pluralize.to_sym
          end

          # Store-scoped where the model is store-owned; option types and other
          # global reference data have no store column and are shared.
          def scope
            klass = model_class
            klass.respond_to?(:for_store) ? klass.for_store(current_store).all : klass.all
          end

          # Nothing to eager-load: coverage reads the translation tables in one
          # grouped query, not through each record's association.
          def collection_includes
            []
          end

          private

          def translatable_locales
            (current_store.supported_locales_list - [current_store.default_locale]).sort
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
