module Spree
  module Admin
    class StockLocationsController < ResourceController

      def new
        if Spree::Config[:default_country_id].present?
          @stock_location.country = Spree::Country.find(Spree::Config[:default_country_id])
        else
          @stock_location.country = Spree::Country.find_by_iso('US')
        end
        invoke_callbacks(:new_action, :before)
        respond_with(@object) do |format|
          format.html { render :layout => !request.xhr? }
          format.js   { render :layout => false }
        end
      end

    end
  end
end
