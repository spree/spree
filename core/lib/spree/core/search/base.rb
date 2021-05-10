module Spree
  module Core
    module Search
      class Base
        attr_accessor :properties
        attr_accessor :current_user
        attr_accessor :current_currency

        def initialize(params)
          self.current_currency = Spree::Config[:currency]
          @properties = {}
          prepare(params)
        end

        def retrieve_products
          @products = extended_base_scope.page(page || 1).per(per_page)
        end

        def method_missing(name)
          if @properties.key? name
            @properties[name]
          else
            super
          end
        end

        protected

        def extended_base_scope
          base_scope = Spree::Product.spree_base_scopes
          base_scope = get_products_conditions_for(base_scope, keywords)
          base_scope = Spree::Dependencies.products_finder.constantize.new(
            scope: base_scope,
            params: {
              filter: {
                price: price,
                option_value_ids: option_value_ids,
                properties: product_properties,
                taxons: taxon&.id
              },
              sort_by: sort_by
            },
            current_currency: current_currency
          ).execute
          base_scope = add_search_scopes(base_scope)
          add_eagerload_scopes(base_scope)
        end

        def add_eagerload_scopes(scope)
          scope.includes(
            :tax_category,
            variants: [
              { images: { attachment_attachment: :blob } }
            ],
            master: [
              :prices,
              { images: { attachment_attachment: :blob } }
            ]
          )
        end

        def add_search_scopes(base_scope)
          if search.is_a?(ActionController::Parameters)
            search.each do |name, scope_attribute|
              scope_name = name.to_sym

              base_scope = if base_scope.respond_to?(:search_scopes) && base_scope.search_scopes.include?(scope_name.to_sym)
                             base_scope.send(scope_name, *scope_attribute)
                           else
                             base_scope.merge(Spree::Product.ransack(scope_name => scope_attribute).result)
                           end
            end
          end
          base_scope
        end

        # method should return new scope based on base_scope
        def get_products_conditions_for(base_scope, query)
          unless query.blank?
            base_scope = base_scope.like_any([:name, :description], [query])
          end
          base_scope
        end

        def get_products_option_values_conditions(base_scope, option_value_ids)
          unless option_value_ids.blank?
            base_scope = base_scope.joins(variants: :option_values).where(spree_option_values: { id: option_value_ids })
          end
          base_scope
        end

        def get_price_range(price_param)
          return if price_param.blank?

          less_than_string = I18n.t('activerecord.attributes.spree/product.less_than')

          if price_param.include? less_than_string
            low_price = 0
            high_price = Monetize.parse(price_param.remove("#{less_than_string} ")).to_i
          else
            low_price, high_price = Monetize.parse_collection(price_param).map(&:to_i)
            high_price = Float::INFINITY if high_price&.zero?
          end

          "#{low_price},#{high_price}"
        end

        def build_option_value_ids(params)
          filter_params = Spree::OptionType.filterable.map(&:filter_param)

          filter_params.reduce([]) do |acc, filter_param|
            acc + params[filter_param].to_s.split(',')
          end
        end

        def prepare(params)
          @properties[:taxon] = params[:taxon].blank? ? nil : Spree::Taxon.find(params[:taxon])
          @properties[:keywords] = params[:keywords]
          @properties[:option_value_ids] = build_option_value_ids(params)
          @properties[:price] = get_price_range(params[:price])
          @properties[:search] = params[:search]
          @properties[:sort_by] = params[:sort_by] || 'default'
          @properties[:include_images] = params[:include_images]

          per_page = params[:per_page].to_i
          @properties[:per_page] = per_page > 0 ? per_page : Spree::Config[:products_per_page]
          @properties[:page] = if params[:page].respond_to?(:to_i)
                                 params[:page].to_i <= 0 ? 1 : params[:page].to_i
                               else
                                 1
                               end
          @properties[:product_properties] = params[:properties]
        end
      end
    end
  end
end
