module Spree
  module Api
    module V3
      module Admin
        # Adds the opt-in per-locale translation matrix to an admin serializer
        # for a model that includes +Spree::TranslatableResource+. Include it in
        # every translatable resource's admin serializer (product, option type,
        # category, …) so the +?expand=translations+ surface stays consistent
        # and defined in one place.
        #
        # @example
        #   class ProductSerializer < V3::ProductSerializer
        #     include Spree::Api::V3::Admin::Translatable
        #   end
        module Translatable
          extend ActiveSupport::Concern

          included do
            # locale code => { field => value, translated_field_count } — mirrors
            # the hand-written LocaleTranslations shape, inlined so the generated
            # types need no import from the hand-written barrel.
            typelize translations: 'Record<string, Record<string, string | number | null>>'

            # Full per-locale translation matrix { locale => { field => value } }.
            # Opt-in via ?expand=translations — the matrix (non-default locales ×
            # translatable fields × translation-table joins) is wasteful on list
            # views, so it is never rendered by default. params[:expand] is part
            # of the HTTP cache key, so expanded/non-expanded responses cache
            # separately. Writes go through the dedicated /translations endpoint.
            attribute :translations, if: proc { expand?('translations') } do |record|
              Spree::Translations.matrix_for(record)
            end
          end
        end
      end
    end
  end
end
