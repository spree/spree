module Spree
  module Api
    module V3
      # Resolves the active Spree::Channel for an API request and writes it
      # into +Spree::Current.channel+ so models, scopes, and serializers can
      # read channel context without threading it through method args.
      #
      # Resolution order:
      # 1. The authenticated publishable key's channel binding
      #    (+Spree::ApiKey#channel+) — server-assigned, cannot be overridden;
      #    a +X-Spree-Channel+ header naming a different channel is a 422
      # 2. +X-Spree-Channel+ header value matched against +channels.code+ —
      #    or, if it looks like a prefixed ID (+ch_…+), against +channels.id+
      #    — scoped to the current store
      # 3. +current_store.default_channel+
      #
      # The concern is a no-op if no channel matches — callers fall back to
      # +Spree::Current.channel+'s store-default behavior.
      #
      # IMPORTANT: key-bound resolution requires +authenticate_api_key!+ to run
      # BEFORE +set_current_channel+ — both Store API branches order their
      # callbacks accordingly (prepended in Store::BaseController, inherited
      # ahead of the include in Store::ResourceController).
      module ChannelResolution
        extend ActiveSupport::Concern

        CHANNEL_HEADER = 'X-Spree-Channel'.freeze

        included do
          before_action :set_current_channel
        end

        protected

        def current_channel
          @current_channel ||= channel_from_api_key || channel_from_header || Spree::Current.channel
        end

        private

        # Only write to Spree::Current when the key or header resolves a
        # specific channel. The store-default fallback is handled lazily by
        # +Spree::Current.channel+ itself, which avoids one query per
        # unbound, header-less API request.
        def set_current_channel
          bound = channel_from_api_key

          if bound
            header = channel_from_header
            if header && header.id != bound.id
              render_error(
                code: ErrorHandler::ERROR_CODES[:channel_mismatch],
                message: Spree.t('api.errors.channel_mismatch', default: 'The requested channel does not match the channel this API key is bound to'),
                status: :unprocessable_entity
              )
              return
            end

            unless bound.active?
              render_error(
                code: ErrorHandler::ERROR_CODES[:channel_inactive],
                message: Spree.t('api.errors.channel_inactive', default: 'The channel this API key is bound to is not active'),
                status: :forbidden
              )
              return
            end
          end

          # Memoize so a later +current_channel+ call (e.g. the storefront gate,
          # serializer params) reuses this row instead of re-querying.
          @current_channel = bound || channel_from_header
          Spree::Current.channel = @current_channel if @current_channel
        end

        def channel_from_api_key
          return nil unless respond_to?(:current_api_key, true)

          current_api_key&.channel
        end

        def channel_from_header
          value = request.headers[CHANNEL_HEADER].presence
          return nil if value.blank?
          return nil unless current_store

          scope = current_store.channels.active
          # Accept either a merchant-meaningful +code+ ("pos", "wholesale") or
          # the opaque prefixed ID — mirrors how Store API endpoints accept
          # either slug or prefixed ID (e.g. +products/{slug-or-id}+).
          if Spree::PrefixedId.prefixed_id?(value)
            scope.find_by_prefix_id(value)
          else
            scope.find_by(code: value)
          end
        end
      end
    end
  end
end
