module Spree
  module Api
    class PropertiesController < Spree::Api::BaseController

      before_filter :find_property, :only => [:show, :update, :destroy]

      def index
        @properties = Spree::Property.accessible_by(current_ability, :read).
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
        if @property
          authorize! :update, @property
          @property.update_attributes(params[:property])
          respond_with(@property, :status => 200, :default_template => :show)
        else
          invalid_resource!(@property)
        end
      end

      def destroy
        if @property
          authorize! :destroy, @property
          @property.destroy
          respond_with(@property, :status => 204)
        else
          invalid_resource!(@property)
        end
      end

      private

      def find_property
        @property = Spree::Property.accessible_by(current_ability, :read).find(params[:id])
      rescue ActiveRecord::RecordNotFound
        @property = Spree::Property.accessible_by(current_ability, :read).find_by_name!(params[:id])
      end

    end
  end
end
