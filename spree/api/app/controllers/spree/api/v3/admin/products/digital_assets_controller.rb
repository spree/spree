module Spree
  module Api
    module V3
      module Admin
        module Products
          class DigitalAssetsController < ResourceController
            include Spree::Api::V3::DigitalAssetWrites

            scoped_resource :products

            request_params :digital_asset do |body|
              body.include_attributes Spree::Api::V3::DigitalAssetRequestSchema
              # The model validates it names a registered provider.
              body.attribute :provider_type, :string,
                description: 'A provider shorthand from the providers endpoint. Omit for an uploaded file.'
              # Its keys are declared by the provider, so it lands verbatim
              # under one key in the asset's metadata.
              body.attribute :provider_settings, :hash,
                description: "Values for the provider's settings schema, keyed by field name."
            end

            # GET /api/v3/admin/products/:product_id/digital_assets/providers
            #
            # The sources a merchant can pick for a new asset: the uploaded-file
            # default plus any host-registered provider. Drives the dashboard's
            # source selector; a host with only the default sees just "upload".
            def providers
              authorize! :create, model_class

              data = Spree.digital_asset_providers.map do |provider_class|
                {
                  type: provider_class.api_type,
                  name: provider_class.provider_name,
                  requires_attachment: provider_class.requires_attachment?,
                  settings_schema: provider_class.settings_schema
                }
              end

              render json: { data: data }
            end

            protected

            def serializer_class
              Spree.api.admin_digital_asset_serializer
            end

            def set_parent
              @parent = current_store.products.find_by_prefix_id!(params[:product_id])
              authorize!(:show, @parent)
            end
          end
        end
      end
    end
  end
end
