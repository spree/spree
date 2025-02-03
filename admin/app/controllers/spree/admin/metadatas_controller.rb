module Spree
  module Admin
    class MetadatasController < Spree::Admin::BaseController
      before_action :set_resource, only: [:edit, :update]
      before_action :load_data, only: [:edit]

      def edit; end

      def update
        if @resource.update(private_metadata: metadata_params(:private), public_metadata: metadata_params(:public))
          flash[:success] = flash_message_for(@resource, :successfully_updated)
          redirect_to spree.edit_admin_metadata_path(
            @resource,
            resource_type: @resource.class.to_s
          )
        else
          flash.now[:error] = @resource.errors.full_messages.join(', ')
          render :edit
        end
      end

      private

      def metadata_params(type)
        metadata_params = params.permit("#{type}_metadata" => {}).permit!.to_h
        metadata_params["#{type}_metadata"]&.each_with_object({}) do |(_i, m), o|
          if m[:value].present?
            o[m[:key]] = m[:value]
          end
        end || {}
      end

      def public_metadata
        params.permit(:public_metadata).permit!
      end

      def resource_class
        @resource_class ||= params[:resource_type].constantize
      end

      def set_resource
        @resource = if resource_class.respond_to?(:friendly)
                      resource_class.friendly.find(params[:id])
                    else
                      resource_class.find(params[:id])
                    end
      end

      def load_data
        case @resource
        when Spree::Product
          @resource_name = @resource.name
          @back_path = spree.edit_admin_product_path(@resource)
        when Spree::User
          @resource_name = @resource.name
          @back_path = spree.admin_user_path(@resource)
        when Spree::Vendor
          @resource_name = @resource.name
          @back_path = spree.admin_vendor_path(@resource)
        when Spree::OptionType
          @resource_name = @resource.presentation
          @back_path = spree.edit_admin_option_type_path(@resource)
        when Spree::Order
          @resource_name = @resource.number
          @back_path = spree.edit_admin_order_path(@resource)
        when Spree::Taxon
          @resource_name = @resource.name
          @back_path = spree.edit_admin_taxonomy_taxon_path(@resource.taxonomy, @resource.id)
        when Spree::Taxonomy
          @resource_name = @resource.name
          @back_path = spree.edit_admin_taxonomy_path(@resource)
        when Spree::Store
          @resource_name = @resource.name
          @back_path = spree.edit_admin_store_path(@resource, section: 'general-settings')
        end
      end
    end
  end
end
