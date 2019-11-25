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
          @products = get_extended_base_scope&.available
          curr_page = page || 1

          unless Spree::Config.show_products_without_price
            @products = @products.where('spree_prices.amount IS NOT NULL').
                        where('spree_prices.currency' => current_currency)
          end
          @products = @products.page(curr_page).per(per_page)
        end

        def method_missing(name)
          if @properties.key? name
            @properties[name]
          else
            super
          end
        end

        protected

        def get_extended_base_scope
          base_scope = Spree::Product.spree_base_scopes.active
          base_scope = get_products_conditions_for(base_scope, keywords)
          base_scope = Spree::Products::Find.new(
            scope: base_scope,
            params: {
              filter: {
                price: price,
                option_value_ids: option_value_ids,
                taxons: taxon&.id
              },
              sort_by: sort_by
            },
            current_currency: current_currency).execute
          base_scope = add_search_scopes(base_scope)
          base_scope = add_eagerload_scopes(base_scope)
          base_scope
        end

        def add_eagerload_scopes(scope)
          # TL;DR Switch from `preload` to `includes` as soon as Rails starts honoring
          # `order` clauses on `has_many` associations when a `where` constraint
          # affecting a joined table is present (see
          # https://github.com/rails/rails/issues/6769).
          #
          # Ideally this would use `includes` instead of `preload` calls, leaving it
          # up to Rails whether associated objects should be fetched in one big join
          # or multiple independent queries. However as of Rails 4.1.8 any `order`
          # defined on `has_many` associations are ignored when Rails builds a join
          # query.
          #
          # Would we use `includes` in this particular case, Rails would do
          # separate queries most of the time but opt for a join as soon as any
          # `where` constraints affecting joined tables are added to the search;
          # which is the case as soon as a taxon is added to the base scope.
          scope = scope.preload(master: { images: { attachment_attachment: :blob } }) if include_images
          scope
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

          if price_param == 'Less than $50'
            low_price = 0
            high_price = 50
          else
            low_price, high_price = price_param.remove('$').split(' - ')
          end
          "#{low_price},#{high_price}"
        end

        def prepare(params)
          @properties[:taxon] = params[:taxon].blank? ? nil : Spree::Taxon.find(params[:taxon])
          @properties[:keywords] = params[:keywords]
          colors = params[:color]&.split(',') || []
          sizes = params[:size]&.split(',') || []
          lengths = params[:length]&.split(',') || []
          @properties[:option_value_ids] = colors | sizes | lengths
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
        end
      end
    end
  end
end
