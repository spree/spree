module Spree
  module Admin
    class UsersController < ResourceController

      # http://spreecommerce.com/blog/2010/11/02/json-hijacking-vulnerability/
      before_filter :check_json_authenticity, :only => :index
      before_filter :load_roles, :only => [:edit, :new, :update, :create]

      update.after :sign_in_if_change_own_password

      def index
        respond_with(@collection) do |format|
          format.html
          format.json { render :json => json_data }
        end
      end

      def dismiss_banner
        if request.xhr? and params[:banner_id]
          current_user.dismiss_banner(params[:banner_id])
          render :nothing => true
        end
      end

      protected

        def collection
          return @collection if @collection.present?
          unless request.xhr?
            @search = Spree::User.registered.metasearch(params[:search])
            @collection = @search.relation.page(params[:page]).per(Spree::Config[:admin_products_per_page])
          else
            #disabling proper nested include here due to rails 3.1 bug
            #@collection = User.includes(:bill_address => [:state, :country], :ship_address => [:state, :country]).
            @collection = Spree::User.includes(:bill_address, :ship_address).
                              where("spree_users.email #{LIKE} :search
                                     OR (spree_addresses.firstname #{LIKE} :search AND spree_addresses.id = spree_users.bill_address_id)
                                     OR (spree_addresses.lastname  #{LIKE} :search AND spree_addresses.id = spree_users.bill_address_id)
                                     OR (spree_addresses.firstname #{LIKE} :search AND spree_addresses.id = spree_users.ship_address_id)
                                     OR (spree_addresses.lastname  #{LIKE} :search AND spree_addresses.id = spree_users.ship_address_id)",
              { :search => "#{params[:q].strip}%" }).
                limit(params[:limit] || 100)
            end
          end

      private

        # handling raise from Admin::ResourceController#destroy
        def user_destroy_with_orders_error
          invoke_callbacks(:destroy, :fails)
          render :status => :forbidden, :text => t(:error_user_destroy_with_orders)
        end

        # Allow different formats of json data to suit different ajax calls
        def json_data
          json_format = params[:json_format] or 'default'
          case json_format
          when 'basic'
            collection.map { |u| { 'id' => u.id, 'name' => u.email } }.to_json
          else
            address_fields = [:firstname, :lastname, :address1, :address2, :city, :zipcode, :phone, :state_name, :state_id, :country_id]
            includes = { :only => address_fields , :include => { :state => { :only => :name }, :country => { :only => :name } } }

            collection.to_json(:only => [:id, :email], :include =>
                               { :bill_address => includes, :ship_address => includes })
          end
        end

        def load_roles
          @roles = Role.all
        end

        def sign_in_if_change_own_password
          if current_user == @user && @user.password.present?
            sign_in(@user, :event => :authentication, :bypass => true)
          end
        end
    end
  end
end
