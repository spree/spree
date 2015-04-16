module Spree
  module Api
    module V2
      class PropertiesController < Spree::Api::BaseController

        before_action :find_property, only: [:show, :update, :destroy]

        def index
          @properties = Spree::Property.accessible_by(current_ability, :read)

          if params[:ids]
            @properties = @properties.where(id: params[:ids].split(",").flatten)
          else
            @properties = @properties.ransack(params[:q]).result
          end

          @properties = @properties.page(params[:page]).per(params[:per_page])
          render json: @properties, meta: pagination(@properties)
        end

        def show
          render json: @property
        end

        def new
        end

        def create
          authorize! :create, Property
          @property = Spree::Property.new(property_params)
          if @property.save
            render json: @property, status: 201
          else
            invalid_resource!(@property)
          end
        end

        def update
          if @property
            authorize! :update, @property
            @property.update_attributes(property_params)
            render json: @property
          else
            invalid_resource!(@property)
          end
        end

        def destroy
          if @property
            authorize! :destroy, @property
            @property.destroy
            render nothing: true, status: 204
          else
            invalid_resource!(@property)
          end
        end

        private

          def find_property
            @property = Spree::Property.accessible_by(current_ability, :read).find(params[:id])
          rescue ActiveRecord::RecordNotFound
            @property = Spree::Property.accessible_by(current_ability, :read).find_by!(name: params[:id])
          end

          def property_params
            params.require(:property).permit(permitted_property_attributes)
          end
      end
    end
  end
end
