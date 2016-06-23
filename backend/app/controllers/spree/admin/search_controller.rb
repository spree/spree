module Spree
  module Admin
    class SearchController < Spree::Admin::BaseController
      respond_to :json
      layout false

      # http://spreecommerce.com/blog/2010/11/02/json-hijacking-vulnerability/
      before_action :check_json_authenticity, only: :index

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
