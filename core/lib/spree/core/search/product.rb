module Spree
  module Core
    module Search
      class Product < Base

        def initialize(params)
          super
          prepare(params)
        end

        def search
          @products = get_base_scope
          curr_page = params[:page] || 1

          unless Spree::Config.show_products_without_price
            @products = @products.where("spree_prices.amount IS NOT NULL").where("spree_prices.currency" => current_currency)
          end
          @products = @products.page(curr_page).per(params[:per_page])
        end

        protected

        def add_eagerload_scopes scope
          if include_images
            scope.includes({master: [:prices, :images]})
          else
            scope.includes(master: :prices)
          end
        end

        def add_search_scopes(base_scope)
          search.each do |name, scope_attribute|
            scope_name = name.to_sym
            if base_scope.respond_to?(:search_scopes) && base_scope.search_scopes.include?(scope_name.to_sym)
              base_scope = base_scope.send(scope_name, *scope_attribute)
            else
              base_scope = base_scope.merge(Spree::Product.ransack({scope_name => scope_attribute}).result)
            end
          end if search
          base_scope
        end

        def get_base_scope
          base_scope = Spree::Product.active
          base_scope = base_scope.in_taxon(@params[:taxon]) if @params[:taxon].present?
          base_scope = get_products_conditions_for(base_scope, @params[:keywords])
          base_scope = add_search_scopes(base_scope)
          base_scope = add_eagerload_scopes(base_scope)
          base_scope
        end

        # method should return new scope based on base_scope
        def get_products_conditions_for(base_scope, query)
          unless query.blank?
            base_scope = base_scope.like_any([:name, :description], query.split)
          end
          base_scope
        end

        def prepare(params)
          @params[:taxon] = params[:taxon].blank? ? nil : Spree::Taxon.find(params[:taxon])

          per_page = params[:per_page].to_i
          @params[:per_page] = per_page > 0 ? per_page : Spree::Config[:products_per_page]
          @params[:page] = (params[:page].to_i <= 0) ? 1 : params[:page].to_i
        end
      end
    end
  end
end
