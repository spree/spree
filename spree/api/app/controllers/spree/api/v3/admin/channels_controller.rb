module Spree
  module Api
    module V3
      module Admin
        class ChannelsController < ResourceController
          include Spree::Api::V3::LegacyPreferenceParams

          accepts_legacy_preference_params Spree::Channel

          scoped_resource :settings

          request_params :channel do
            string :name, required: :create, example: 'Point of Sale'
            string :code, example: 'pos', description: 'URL-safe slug, derived from `name` when blank (`Point of Sale` becomes `point-of-sale`).'
            boolean :active, :default
            string :order_routing_strategy, nullable: true,
                                            description: 'Order routing strategy shorthand (built-in: `rules`). Null inherits the store setting.'
            string :storefront_access, nullable: true, enum: Spree::Channel::Gating::STOREFRONT_ACCESS,
                                       description: 'What anonymous visitors can see. Null inherits the store setting.'
            boolean :guest_checkout, nullable: true,
                                     description: 'Whether guests can check out without an account. Null inherits the store setting.'
            id :default_catalog_id, nullable: true,
                                    description: 'Catalog (`cat_...`) shown to shoppers no company or customer group catalog covers. Null means every product published on the channel.'
            id :stock_location_ids, array: true,
                                    description: 'Stock locations (`sloc_...`) that fulfill this channel. Replaces the whole set; an empty list means every location of the store.'
          end

          request_params 'ChannelAddProductsParams', action: :add_products do
            id :product_ids, array: true, required: true
            datetime :published_at, nullable: true, description: 'When the publications go live. Null means immediately.'
            datetime :unpublished_at, nullable: true, description: 'When the publications come down. Null means never.'
          end

          request_params 'ChannelRemoveProductsParams', action: :remove_products do
            id :product_ids, array: true, required: true
          end

          # POST /api/v3/admin/channels/:id/add_products
          def add_products
            channel = find_resource
            authorize! :update, channel

            count = channel.add_products(
              scoped_product_ids,
              published_at: params[:published_at].presence,
              unpublished_at: params[:unpublished_at].presence
            )
            render json: { product_count: count }
          end

          # POST /api/v3/admin/channels/:id/remove_products
          def remove_products
            channel = find_resource
            authorize! :update, channel

            removed = channel.remove_products(scoped_product_ids)
            render json: { product_count: removed }
          end

          def create
            @resource = model_class.new(assignable_params.merge(store: current_store))
            authorize_resource!(@resource, :create)

            if @resource.save
              render json: serialize_resource(@resource), status: :created
            else
              render_validation_error(@resource.errors)
            end
          end

          def update
            @resource.assign_attributes(assignable_params)

            if @resource.save
              render json: serialize_resource(@resource)
            else
              render_validation_error(@resource.errors)
            end
          end

          protected

          def model_class
            Spree::Channel
          end

          def serializer_class
            Spree.api.admin_channel_serializer
          end

          def permitted_params
            params.permit(*permitted_attributes)
          end

          # `stock_location_ids` replaces the channel's fulfillment-origin
          # allowlist; empty clears it (= every location). Store-scoped
          # resolution: a foreign location 404s.
          def assignable_params
            attributes = permitted_params.except(:stock_location_ids)

            # An incidental lookup like any other: a foreign catalog 404s.
            if attributes.key?(:default_catalog_id)
              attributes[:default_catalog_id] =
                if attributes[:default_catalog_id].present?
                  current_store.catalogs.find_by_prefix_id!(attributes[:default_catalog_id]).id
                else
                  nil
                end
            end

            if params.key?(:stock_location_ids)
              attributes[:stock_locations] = Array(params[:stock_location_ids]).map do |id|
                current_store.stock_locations.accessible_by(current_ability, :show).find_by_prefix_id!(id)
              end
            end

            attributes
          end

          private

          # Scoped to the current store: a product can only be published to a
          # channel of the store that owns it (products are single-owner via
          # `belongs_to :store`). Foreign product IDs are silently dropped.
          def scoped_product_ids
            ids = decode_prefixed_ids(params[:product_ids])
            current_store.products.accessible_by(current_ability, :update).where(id: ids).ids
          end
        end
      end
    end
  end
end
