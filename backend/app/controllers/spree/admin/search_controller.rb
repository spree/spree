module Spree
  module Admin
    class SearchController < Spree::Admin::BaseController
      respond_to :json
      layout false

      # http://spreecommerce.com/blog/2010/11/02/json-hijacking-vulnerability/
      before_action :check_json_authenticity, only: :index

      # TODO: Clean this up by moving searching out to user_class_extensions
      # And then JSON building with something like Active Model Serializers
      def users
        if params[:ids]
          @users = Spree.user_class.where(id: params[:ids].split(',').flatten)
        else
          @users = Spree.user_class.ransack({
            m: 'or',
            email_start: params[:q],
            ship_address_firstname_start: params[:q],
            ship_address_lastname_start: params[:q],
            bill_address_firstname_start: params[:q],
            bill_address_lastname_start: params[:q]
          }).result.limit(10)
        end
      end

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
    end
  end
end

