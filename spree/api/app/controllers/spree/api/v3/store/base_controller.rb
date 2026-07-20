module Spree
  module Api
    module V3
      module Store
        class BaseController < Spree::Api::V3::BaseController
          # Channel resolution is a Store API concern — admin endpoints return
          # data across all channels and filter via Ransack instead. Including
          # this here keeps the +X-Spree-Channel+ header from accidentally
          # narrowing admin queries.
          include Spree::Api::V3::ChannelResolution
          # Mirrors Store::ResourceController. Both branches must carry the gate so
          # login_required / prices_hidden apply to every Store endpoint, not just
          # ResourceController ones. Public endpoints opt out with
          # +allow_guest_storefront_access!+.
          include Spree::Api::V3::StorefrontGating

          # Require publishable API key for all Store API requests. Prepended so
          # the key is authenticated BEFORE ChannelResolution's
          # +set_current_channel+ and the StorefrontGating 401 guard run —
          # a channel-bound key must resolve its channel ahead of the gate, and
          # this matches Store::ResourceController, where +authenticate_request!+
          # is inherited ahead of both concerns.
          prepend_before_action :authenticate_api_key!
        end
      end
    end
  end
end
