module Spree
  module Api
    module V3
      module Store
        # Exposes the channel context the request resolved to (bound key →
        # X-Spree-Channel header → store default) so a storefront can read its
        # own identity and access posture. Deliberately a singular resource:
        # the Store API never enumerates a store's channels — that would leak
        # the existence of gated surfaces (wholesale, POS) to anyone holding
        # the publishable key.
        class ChannelController < Store::BaseController
          # A gated storefront must be able to read "this channel requires
          # login" before authentication to render a sign-in wall instead of
          # an error page.
          allow_guest_storefront_access!

          # GET /api/v3/store/channel
          def show
            render json: serialize_resource(current_channel)
          end

          protected

          def serializer_class
            Spree.api.channel_serializer
          end
        end
      end
    end
  end
end
