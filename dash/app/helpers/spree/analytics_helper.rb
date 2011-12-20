module Spree
  module AnalyticsHelper

    def spree_analytics
      render :partial => 'analytics/header'
    end

    def analytics_tags
      tags = { :id => Spree::Dash::Config.site_id.to_s }
      tags.merge! product_analytics_tags
      tags.merge! taxon_analytics_tags
      tags.merge! keywords_analytics_tags
      tags.merge! cart_analytics_tags
      tags.merge! completed_analytics_tags
    end

    def product_analytics_tags
      return {} unless @product
      { :product => { :name => @product.name,
                      :price => @product.price,
                      :sku => @product.sku,
                      :categories => @product.taxons.map { |t| t.permalink }
                    }
      }
    end

    def taxon_analytics_tags
      return {} unless @taxon
      { :category => { :name => @taxon.permalink } }
    end

    def keywords_analytics_tags
      return {} unless params[:keywords]
      { :search => { :keyword => params[:keywords] } }
    end

    def cart_analytics_tags
      return {} unless @order and @order.cart?
      { :cart => { :total => @order.total,
                   :products => products_for_order }
      }
    end

    def completed_analytics_tags
      return {} unless @order and @order.complete?
      { :confirm => { :orderid => @order.number,
                      :total => @order.total,
                      :shipping => @order.ship_total,
                      :tax => @order.tax_total,
                      :discount => @order.adjustment_total,
                      :subtotal => @order.item_total,
                      :products => products_for_order }
      }
    end

    def products_for_order
      @order.line_items.map do |line_item|
        variant = line_item.variant
        { :name => variant.name,
          :qty => line_item.quantity,
          :price => variant.price,
          :sku => variant.sku,
          :categories => variant.product.taxons.map { |t| t.permalink }
        }
      end
    end

  end
end
