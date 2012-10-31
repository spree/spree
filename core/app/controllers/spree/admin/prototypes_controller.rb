module Spree
  module Admin
    class PrototypesController < ResourceController
      def show
        if request.xhr?
          render :layout => false
        else
          redirect_to admin_prototypes_path
        end
      end

      def available
        @prototypes = Prototype.order('name asc')
        respond_with(@prototypes) do |format|
          format.html { render :layout => !request.xhr? }
          format.js
        end
      end

      def select
        @prototype ||= Prototype.find(params[:id])
        @prototype_properties = @prototype.properties
      end

    end
  end
end
