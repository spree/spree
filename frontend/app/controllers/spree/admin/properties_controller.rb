module Spree
  module Admin
    class PropertiesController < ResourceController

      # Looks like this action is unused
      def filtered
        @properties = Property.where('lower(name) LIKE ?', "%#{params[:q].mb_chars.downcase}%").order(:name)
        respond_with(@properties) do |format|
          format.html { render :template => "spree/admin/properties/filtered", :formats => [:html], :handlers => [:erb], :layout => false }
        end
      end
    end
  end
end
