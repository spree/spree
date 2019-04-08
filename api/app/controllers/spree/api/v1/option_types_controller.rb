module Spree
  module Api
    module V1
      class OptionTypesController < Spree::Api::BaseController
        def index
          @option_types =  if params[:ids]
                             Spree::OptionType.
                               includes(:option_values).
                               accessible_by(current_ability).
                               where(id: params[:ids].split(','))
                           else
                             Spree::OptionType.
                               includes(:option_values).
                               accessible_by(current_ability).
                               load.ransack(params[:q]).result
                           end
          respond_with(@option_types)
        end

        def show
          @option_type = Spree::OptionType.accessible_by(current_ability, :show).find(params[:id])
          respond_with(@option_type)
        end

        def new; end

        def create
          authorize! :create, Spree::OptionType
          @option_type = Spree::OptionType.new(option_type_params)
          if @option_type.save
            render :show, status: 201
          else
            invalid_resource!(@option_type)
          end
        end

        def update
          @option_type = Spree::OptionType.accessible_by(current_ability, :update).find(params[:id])
          if @option_type.update(option_type_params)
            render :show
          else
            invalid_resource!(@option_type)
          end
        end

        def destroy
          @option_type = Spree::OptionType.accessible_by(current_ability, :destroy).find(params[:id])
          @option_type.destroy
          render plain: nil, status: 204
        end

        private

        def option_type_params
          params.require(:option_type).permit(permitted_option_type_attributes)
        end
      end
    end
  end
end
