module Spree
  module Core
    module Search
      class Base
        attr_accessor :properties

        def initialize(params)
          @properties = {}
          prepare(params)
        end

        def retrieve_products
          @products_scope = get_base_scope
          curr_page = page || 1

          @products = @products_scope.includes([:master]).page(curr_page).per(per_page)
        end

        def method_missing(name)
          if @properties.has_key? name
            @properties[name]
          else
            super
          end
        end

        protected
          def get_base_scope
            base_scope = Spree::Product.active
            base_scope = base_scope.in_taxon(taxon) unless taxon.blank?
            base_scope = get_products_conditions_for(base_scope, keywords) unless keywords.blank?
            base_scope = base_scope.on_hand unless Spree::Config[:show_zero_stock_products]
            base_scope = add_search_scopes(base_scope)
            base_scope
          end

          def add_search_scopes(base_scope)
            search.each do |name, scope_attribute|
              next if name.to_s =~ /eval|send|system/

              scope_name = name.intern
              if base_scope.respond_to? scope_name
                base_scope = base_scope.send(scope_name, *scope_attribute)
              else
                base_scope = base_scope.merge(Spree::Product.search({scope_name => scope_attribute}).result)
              end
            end if search
            base_scope
          end

          # method should return new scope based on base_scope
          def get_products_conditions_for(base_scope, query)
            base_scope.like_any([:name, :description], query.split)
          end

          def prepare(params)
            @properties[:taxon] = params[:taxon].blank? ? nil : Spree::Taxon.find(params[:taxon])
            @properties[:keywords] = params[:keywords]
            @properties[:search] = params[:search]

            per_page = params[:per_page].to_i
            @properties[:per_page] = per_page > 0 ? per_page : Spree::Config[:products_per_page]
            @properties[:page] = (params[:page].to_i <= 0) ? 1 : params[:page].to_i

            # if !params[:order_by_price].blank?
            #   @product_group = Spree::ProductGroup.new.from_route([params[:order_by_price] + '_by_master_price'])
            # elsif params[:product_group_name]
            #   @cached_product_group = Spree::ProductGroup.find_by_permalink(params[:product_group_name])
            #   @product_group = Spree::ProductGroup.new
            # elsif params[:product_group_query]
            #   @product_group = Spree::ProductGroup.new.from_route(params[:product_group_query].split('/'))
            # else
            #   @product_group = Spree::ProductGroup.new
            # end
            # @product_group = @product_group.from_search(params[:search]) if params[:search]
          end
      end
    end
  end
end
