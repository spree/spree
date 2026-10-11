module Spree
  module Api
    module V3
      module Admin
        # Admin Markets surface. Markets are store-scoped (`store_id` column +
        # `acts_as_list scope: :store_id`), so the base ResourceController's
        # `scope` chain narrows appropriately when we restrict to
        # `current_store.markets`.
        #
        # `country_codes` and `supported_locales` are accepted as arrays on the
        # wire and translated by model setters (`Spree::Market#country_codes=`,
        # `#supported_locales=`).
        class MarketsController < ResourceController
          scoped_resource :settings

          request_params :market do
            string :name, required: :create, example: 'Europe', description: 'Display name, unique within the store.'
            currency :currency, required: :create, example: 'EUR', description: 'ISO 4217 currency code.'
            string :default_locale, required: :create, example: 'de',
                                    description: 'Locale used as the market default. Always part of `supported_locales`.'
            boolean :tax_inclusive, description: 'Display prices with tax included.'
            string :tax_provider, nullable: true, example: 'internal',
                                  description: 'Shorthand of the tax engine that prices this market, from the tax providers endpoint. Null uses the installation default.'
            boolean :default, description: 'Setting true demotes the previous default market of the store.'
            integer :position, description: 'Sort order within the store; lower comes first.'
            string :supported_locales, array: true, example: %w[de en],
                                       description: 'Locales available in this market. The default locale is always included.'
            country :country_codes, array: true, required: :create, example: %w[DE FR],
                                   description: 'ISO 3166-1 alpha-2 codes of the countries in this market. At least one is required.'
          end

          protected

          def model_class
            Spree::Market
          end

          def serializer_class
            Spree.api.admin_market_serializer
          end

          def collection_includes
            [:market_countries]
          end

          def scope
            super.ordered
          end
        end
      end
    end
  end
end
