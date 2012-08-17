module Spree
  module Admin
    class PrototypesController < ResourceController
      after_filter :set_habtm_associations, :only => [:create, :update]

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

        respond_with(@prototypes)
      end

      private

        def set_habtm_associations
          @prototype.property_ids = params[:option_type].blank? ? [] : params[:property][:id]
          @prototype.option_type_ids = params[:option_type].blank? ? [] : params[:option_type][:id]
        end
    end
  end
end
