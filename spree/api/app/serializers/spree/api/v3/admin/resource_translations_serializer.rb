module Spree
  module Api
    module V3
      module Admin
        # Serializes a translatable record's translation payload — the locale ×
        # field matrix, optionally with self-describing discovery +fields+, the
        # locale envelope, and nested translatable +children+.
        #
        # Params select the shape:
        # - +fields: true+ — include +fields+ (key/type/source) and nested
        #   +children+ (e.g. an option type's option values). The read endpoint
        #   (`GET …/:id/translations`) uses this so an editor fetches the whole
        #   tree in one request.
        # - +envelope: true+ — include +default_locale+/+supported_locales+ from
        #   the record's own translatable store (so they can't contradict the
        #   matrix). The top-level read node and each batch-write echo carry it;
        #   nested children do not.
        #
        # The batch write echo passes +fields: false+ (matrix only); the read
        # endpoint passes both true at the top level and re-renders children
        # with +envelope: false+.
        #
        # Deliberately does NOT include Typelizer::DSL: the payload is computed
        # (matrix/fields/children resolve to `unknown`), so the admin-sdk ships
        # richer hand-written types in `src/types/translations.ts` instead.
        # Without the DSL, Typelizer never enumerates this serializer.
        class ResourceTranslationsSerializer
          include Alba::Resource

          attribute :resource_id, &:prefixed_id

          attribute :resource_type do |record|
            Spree::Translations.public_resource_type(record.class)
          end

          attribute :translations do |record|
            Spree::Translations.matrix_for(record)
          end

          attribute :fields, if: proc { params[:fields] } do |record|
            Spree::Translations.fields_for(record)
          end

          attribute :default_locale, if: proc { params[:envelope] } do |record|
            locale_store(record).default_locale
          end

          attribute :supported_locales, if: proc { params[:envelope] } do |record|
            locale_store(record).supported_locales_list
          end

          attribute :children, if: proc { |record| params[:fields] && children_for(record).any? } do |record|
            # Children carry their own fields + matrix, but not the locale
            # envelope (that's a property of the top-level request, not each row).
            # Recurse with self.class so a swapped subclass renders children too.
            child_params = params.merge(envelope: false)
            children_for(record).map { |child| self.class.new(child, params: child_params).to_h }
          end

          private

          # The store whose locales the payload reports — the record's own
          # translatable store, falling back to the current store.
          def locale_store(record)
            record.translatable_store || params[:store]
          end

          def children_for(record)
            assoc = record.class.try(:translatable_children)
            assoc.present? ? Array(record.public_send(assoc)) : []
          end
        end
      end
    end
  end
end
