module Spree
  module Api
    class OptionTypesController < Spree::Api::BaseController
      def index
        if params[:ids]
          @option_types = Spree::OptionType.where(:id => params[:ids])
        else
          @option_types = Spree::OptionType.scoped.ransack(params[:q]).result
        end
        respond_with(@option_types)
      end

      def show
      	@option_type = Spree::OptionType.find(params[:id])
      	respond_with(@option_type)
      end

      def create
      	authorize! :create, Spree::OptionType
      	@option_type = Spree::OptionType.new(params[:option_type])
        if @option_type.save
          render :show, :status => 201
        else
          invalid_resource!(@option_type)
        end
      end

      def update
        authorize! :update, Spree::OptionType
        @option_type = Spree::OptionType.find(params[:id])
        if @option_type.update_attributes(params[:option_type])
          render :show
        else
          invalid_resource!(@option_type)
        end
      end

      def destroy
        authorize! :destroy, Spree::OptionType
        @option_type = Spree::OptionType.find(params[:id])
        @option_type.destroy
        render :text => nil, :status => 204
      end
    end
  end
end
