class Api::OrdersController < Api::BaseController
  before_filter :access_denied, :except => [:index, :show]

  private
    def find_resource
      Spree::Order.find_by_param(params[:id])
    end

    def object_serialization_options
      { :include => {
          :bill_address => { :include => [:country, :state] },
          :ship_address => { :include => [:country, :state] },
          :shipments => { :include => [:shipping_method, :address] },
          :line_items => { :include => [:variant] }
          }
      }
    end

end
