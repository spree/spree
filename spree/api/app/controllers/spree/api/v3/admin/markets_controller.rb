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

          request_params :market do |body|
            body.attribute :name, :string,
              required: true, on: :create,
              example: 'Europe',
              description: 'Display name, unique within the store.'
            body.attribute :currency, :currency,
              required: true, on: :create,
              example: 'EUR',
              description: 'ISO 4217 currency code.'
            body.attribute :default_locale, :locale,
              required: true, on: :create,
              example: 'de',
              description: 'Locale used as the market default. Always part of `supported_locales`.'
            body.attribute :tax_inclusive, :boolean, description: 'Display prices with tax included.'
            body.attribute :tax_provider, :string,
              nullable: true,
              example: 'internal',
              description: 'Shorthand of the tax engine that prices this market, from the tax providers endpoint. Null uses the installation default.'
            body.attribute :default, :boolean,
              description: 'Setting true demotes the previous default market of the store.'
            body.attribute :position, :integer, description: 'Sort order within the store; lower comes first.'
            body.attribute :supported_locales, :array, of: :locale,
              example: %w[de en],
              description: 'Locales available in this market. The default locale is always included.'
            body.attribute :country_codes, :array, of: :country,
              required: true, on: :create,
              example: %w[DE FR],
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
