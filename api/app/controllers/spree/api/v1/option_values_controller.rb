module Spree
  module Api
    class OptionValuesController < Spree::Api::BaseController
      def index
        if params[:ids]
          @option_values = scope.where(:id => params[:ids])
        else
          @option_values = scope.ransack(params[:q]).result.distinct
        end
        respond_with(@option_values)
      end

      def show
        @option_value = scope.find(params[:id])
        respond_with(@option_value)
      end

      def create
        authorize! :create, Spree::OptionValue
        @option_value = scope.new(option_value_params)
        if @option_value.save
          render :show, :status => 201
        else
          invalid_resource!(@option_value)
        end
      end

      def update
        @option_value = scope.accessible_by(current_ability, :update).find(params[:id])
        if @option_value.update_attributes(option_value_params)
          render :show
        else
          invalid_resource!(@option_value)
        end
      end

      def destroy
        @option_value = scope.accessible_by(current_ability, :destroy).find(params[:id])
        @option_value.destroy
        render :text => nil, :status => 204
      end

      private

        def scope
          if params[:option_type_id]
            @scope ||= Spree::OptionType.find(params[:option_type_id]).option_values.accessible_by(current_ability, :read)
          else
            @scope ||= Spree::OptionValue.accessible_by(current_ability, :read).load
          end
        end

        def option_value_params
          params.require(:option_value).permit(permitted_option_value_attributes)
        end
    end
  end
end
