module Spree
  module Api
    class PropertiesController < Spree::Api::BaseController
      respond_to :json

      before_filter :find_property, :only => [:show, :update, :destroy]

      def index
        @properties = Spree::Property.
                      ransack(params[:q]).result.
                      page(params[:page]).per(params[:per_page])
        respond_with(@properties)
      end

      def show
        respond_with(@property)
      end

      def new
      end

      def create
        authorize! :create, Property
        @property = Spree::Property.new(params[:property])
        if @property.save
          respond_with(@property, :status => 201, :default_template => :show)
        else
          invalid_resource!(@property)
        end
      end

      def update
        authorize! :update, Property
        if @property && @property.update_attributes(params[:property])
          respond_with(@property, :status => 200, :default_template => :show)
        else
          invalid_resource!(@property)
        end
      end

      def destroy
        authorize! :delete, Property
        if(@property)
          @property.destroy
          respond_with(@property, :status => 204)
        else
          invalid_resource!(@property)
        end
      end

      private

      def find_property
        @property = Spree::Property.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        @property = Spree::Property.find_by_name!(params[:id])
      end

    end
  end
end
