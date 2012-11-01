module Spree
  module Admin
    class PropertiesController < ResourceController

      # Looks like this action is unused
      def filtered
        @properties = Property.where('lower(name) LIKE ?', "%#{params[:q].mb_chars.downcase}%").order(:name)
        render :template => "spree/admin/properties/filtered", :layout => false
      end
    end
  end
end
