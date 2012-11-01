module Spree
  module Admin
    class SearchController < Spree::Admin::BaseController
      # http://spreecommerce.com/blog/2010/11/02/json-hijacking-vulnerability/
      before_filter :check_json_authenticity, :only => :index
      respond_to :json

      # TODO: Clean this up by moving searching out to user_class_extensions
      # And then JSON building with something like Active Model Serializers
      def users
        @users = Spree.user_class.ransack({
          :m => 'or',
          :email_start => params[:q],
          :ship_address_firstname_start => params[:q],
          :ship_address_lastname_start => params[:q],
          :bill_address_firstname_start => params[:q],
          :bill_address_lastname_start => params[:q]
        }).result.limit(params[:limit] || 100)
      end
    end
  end
end

