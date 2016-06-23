module Spree
  module Admin
    class SearchController < Spree::Admin::BaseController
      respond_to :json
      layout false

      # http://spreecommerce.com/blog/2010/11/02/json-hijacking-vulnerability/
      before_action :check_json_authenticity, only: :index

      def products
        if params[:ids]
          @products = Product.where(id: params[:ids].split(",").flatten)
        else
          @products = Product.ransack(params[:q]).result
        end

        @products = @products.distinct.page(params[:page]).per(params[:per_page])
        expires_in 15.minutes, public: true
        headers['Surrogate-Control'] = "max-age=#{15.minutes}"
      end

      def tags
        @tags =
          if params[:ids]
            Tag.where(id: params[:ids].split(",").flatten)
          else
            Tag.ransack(params[:q]).result
          end
      end
    end
  end
end
