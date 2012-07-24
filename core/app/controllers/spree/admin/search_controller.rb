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

        respond_with(@users) do |format|
          format.json do
            address_fields = [:firstname, :lastname,
                              :address1, :address2,
                              :city, :zipcode,
                              :phone, :state_name,
                              :state_id, :country_id]
            includes = {
              :only => address_fields,
              :include => {
                :state => { :only => :name },
                :country => { :only => :name }
              }
            }

          json = @users.to_json({
            :only => [:id, :email],
            :include => { :bill_address => includes, :ship_address => includes }
          })

          render :json => json
          end
        end
      end
    end
  end
end

