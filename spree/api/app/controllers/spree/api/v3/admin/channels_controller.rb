module Spree
  module Api
    module V3
      module Admin
        class ChannelsController < ResourceController
          scoped_resource :settings

          # POST /api/v3/admin/channels/:id/add_products
          # Body: { product_ids: [...], published_at: nil, unpublished_at: nil }
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
          # Body: { product_ids: [...] }
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

          def scope
            super.for_store(current_store)
          end

          def permitted_params
            params.permit(*model_additional_permitted_attributes, :name, :code, :active, :default, :preferred_order_routing_strategy,
                          :preferred_storefront_access, :preferred_guest_checkout,
                          :default_catalog_id, :default_market_id,
                          stock_location_ids: [], market_ids: [])
          end

          # `stock_location_ids` replaces the channel's fulfillment-origin
          # allowlist; empty clears it (= every location). Store-scoped
          # resolution: a foreign location 404s.
          def assignable_params
            attributes = permitted_params.except(:stock_location_ids, :market_ids)

            # An incidental lookup like any other: a foreign catalog 404s.
            if attributes.key?(:default_catalog_id)
              attributes[:default_catalog_id] =
                if attributes[:default_catalog_id].present?
                  current_store.catalogs.find_by_prefix_id!(attributes[:default_catalog_id]).id
                else
                  nil
                end
            end

            # An incidental lookup like any other: a foreign market 404s.
            if attributes.key?(:default_market_id)
              attributes[:default_market_id] =
                if attributes[:default_market_id].present?
                  current_store.markets.find_by_prefix_id!(attributes[:default_market_id]).id
                else
                  nil
                end
            end

            if params.key?(:stock_location_ids)
              attributes[:stock_locations] = Array(params[:stock_location_ids]).map do |id|
                current_store.stock_locations.accessible_by(current_ability, :show).find_by_prefix_id!(id)
              end
            end

            # `market_ids` replaces the channel's market allowlist; empty
            # clears it (= every market of the store).
            if params.key?(:market_ids)
              attributes[:markets] = Array(params[:market_ids]).map do |id|
                current_store.markets.find_by_prefix_id!(id)
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
