module Spree
  module Api
    module Products
      class FiltersPresenter
        def initialize(current_store, current_currency, params)
          @products_for_filters = find_products_for_filters(current_store, current_currency, params)
        end

        def to_h
          option_values = Spree::OptionValues::FindAvailable.new(products_scope: products_for_filters).execute
          option_values_presenters = Spree::Filters::OptionsPresenter.new(option_values_scope: option_values).to_a
          product_properties = Spree::ProductProperties::FindAvailable.new(products_scope: products_for_filters).execute
          product_properties_presenters = Spree::Filters::PropertiesPresenter.new(product_properties_scope: product_properties).to_a
          {
            option_types: option_values_presenters.map(&:to_h),
            product_properties: product_properties_presenters.map(&:to_h)
          }
        end

        private

        attr_reader :products_for_filters

        def find_products_for_filters(current_store, current_currency, params)
          current_taxons = find_current_taxons(current_store, params)
          current_store.products.active(current_currency).in_taxons(current_taxons)
        end

        def find_current_taxons(current_store, params)
          taxons_param = params.dig(:filter, :taxons)
          return nil if taxons_param.nil? || taxons_param.to_s.blank?

          taxon_ids = taxons_param.to_s.split(',')
          current_store.taxons.where(id: taxon_ids)
        end
      end
    end
  end
end
