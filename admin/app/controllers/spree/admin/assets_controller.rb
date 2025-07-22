module Spree
  module Admin
    class AssetsController < ResourceController
      include Spree::Admin::SessionAssetsHelper

      def create
        @asset = asset_type.new(permitted_resource_params)

        # we only should check this for vendor users
        authorize! :update, @asset.viewable if @asset.viewable.present? && current_vendor

        if @asset.save
          @product = @asset.product || current_store.products.new

          # we need to store the asset ids in the session to be able to display them in the product page
          store_uploaded_asset_in_session(@asset) if @product.new_record?
        else
          flash.now[:error] = @asset.errors.full_messages.to_sentence
          render :create, status: :unprocessable_entity
        end
      end

      def update
        authorize! :update, @asset.viewable if @asset.viewable.present? && current_vendor

        if @asset.update(permitted_resource_params)
          respond_to do |format|
            format.turbo_stream
            format.json { render json: @asset }
          end
        else
          head :unprocessable_entity
        end
      end

      def bulk_destroy
        @assets = model_class.accessible_by(current_ability).where(id: params[:ids])
        @assets.destroy_all
      end

      private

      def permitted_resource_params
        params.require(:asset).permit(Spree::PermittedAttributes.asset_attributes)
      end

      def create_turbo_stream_enabled?
        true
      end

      def update_turbo_stream_enabled?
        true
      end

      def destroy_turbo_stream_enabled?
        true
      end

      def asset_type
        allowed_asset_types.find { |type| type.to_s == permitted_resource_params[:type] } || model_class
      end

      def allowed_asset_types
        [Spree::Asset, Spree::Image]
      end
    end
  end
end
