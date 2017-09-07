module Spree
  module Api
    module V1
      class TagsController < Spree::Api::BaseController
        def index
          @tags =
            if params[:ids]
              Tag.where(id: params[:ids].split(',').flatten)
            else
              Tag.ransack(params[:q]).result
            end

          @tags = @tags.page(params[:page]).per(params[:per_page])

          expires_in 15.minutes, public: true
          headers['Surrogate-Control'] = "max-age=#{15.minutes}"
          respond_with(@tags)
        end

        private

        def tags_params
          params.require(:tag).permit(permitted_tags_attributes)
        end
      end
    end
  end
end
