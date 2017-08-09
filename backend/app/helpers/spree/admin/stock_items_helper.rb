module Spree
  module Admin
    module StockItemsHelper
      def search_params
        params[:q].permit(:variant_product_name_cont, :variant_sku_cont).to_h
      end
    end
  end
end
