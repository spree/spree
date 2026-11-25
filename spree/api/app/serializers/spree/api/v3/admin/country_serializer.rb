module Spree
  module Api
    module V3
      module Admin
        # No timestamps: countries are reference data supplied by the countries
        # gem rather than records, so they have no created_at/updated_at.
        # The dashboard names countries with Intl.DisplayNames in the admin's
        # own language, so the Admin API sends the ISO code alone.
        class CountrySerializer < V3::CountrySerializer
          _attributes.delete(:name)

          typelize currency: [:string, nullable: true, enum: Spree::Money::Rounding::CURRENCY_CODES, enum_type_name: 'CurrencyCode',
                                       comment: "The country's own currency, which a store set up there starts with"],
                   locales: [:string, multi: true, enum: Spree::Locales::ALL, enum_type_name: 'LocaleCode',
                                      comment: "The country's official languages, such as `de`, `fr`, `it` and `rm` for Switzerland"]

          attribute :currency, &:default_currency
          attribute :locales, &:offerable_locales

          many :states,
               resource: proc { Spree.api.admin_state_serializer },
               if: proc { params[:expand]&.include?('states') }
        end
      end
    end
  end
end
