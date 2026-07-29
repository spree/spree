module Spree
  module Api
    module V3
      module Store
        # Storefront delivery method discovery — primarily for pickup flows:
        # list pickup-capable methods, then their pickup locations (merchant
        # stock locations) or third-party pickup points near the customer.
        class DeliveryMethodsController < ResourceController
          # GET /api/v3/store/delivery_methods/:id/pickup_locations
          # Pickup-enabled stock locations. With ?cart_id= the list is
          # narrowed to locations that can fulfill the whole cart from local
          # stock (package-scoped availability).
          def pickup_locations
            locations = find_resource.available_pickup_locations
            locations = locations.select { |location| covers_cart?(location, pickup_cart) } if pickup_cart

            render json: { data: locations.map { |location| Spree.api.stock_location_serializer.new(location, params: serializer_params).to_h } }
          end

          # GET /api/v3/store/delivery_methods/:id/pickup_points?latitude=&longitude=
          def pickup_points
            provider = find_resource.pickup_point_provider_instance
            if provider.nil?
              return render_error(code: ERROR_CODES[:record_not_found], message: Spree.t('errors.messages.no_pickup_point_provider'), status: :not_found)
            end

            latitude = params[:latitude].presence&.to_f
            longitude = params[:longitude].presence&.to_f
            if latitude.nil? || longitude.nil?
              return render_error(code: ERROR_CODES[:parameter_missing], message: 'latitude and longitude are required', status: :bad_request)
            end

            points = provider.find_nearby(latitude: latitude, longitude: longitude)
            render json: { data: points.map(&:to_pickup_point_data) }
          end

          protected

          def model_class
            Spree::DeliveryMethod
          end

          def serializer_class
            Spree.api.delivery_method_serializer
          end

          def scope
            scope = current_store.delivery_methods.storefront_visible
            scope = scope.by_fulfillment_type(params[:fulfillment_type]) if params[:fulfillment_type].present?
            scope
          end

          private

          # Coverage results depend on the cart's contents — the caller must
          # prove access to it (owner JWT or the cart token), like every
          # other cart read.
          def pickup_cart
            return @pickup_cart if defined?(@pickup_cart)
            return @pickup_cart = nil if params[:cart_id].blank?

            cart = current_store.carts.incomplete.find_by_prefix_id!(params[:cart_id])
            authorize!(:show, cart, request.headers['x-spree-token'])
            @pickup_cart = cart
          end

          # 'local' policy: every cart item must be on hand at the location.
          # 'any' policy: the location offers pickup regardless of local stock
          # (the merchant transfers goods in).
          def covers_cart?(location, cart)
            return true if location.pickup_stock_policy == 'any'

            cart.line_items.includes(:variant).all? do |line_item|
              next true unless line_item.variant.should_track_inventory?

              stock_item = location.stock_item(line_item.variant)
              stock_item.present? && stock_item.count_on_hand >= line_item.quantity
            end
          end
        end
      end
    end
  end
end
