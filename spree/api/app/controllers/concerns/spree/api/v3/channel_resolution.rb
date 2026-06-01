module Spree
  module Api
    module V3
      # Resolves the active Spree::Channel for an API request and writes it
      # into +Spree::Current.channel+ so models, scopes, and serializers can
      # read channel context without threading it through method args.
      #
      # Resolution order:
      # 1. +X-Spree-Channel+ header value matched against +channels.code+
      #    scoped to the current store
      # 2. +current_store.default_channel+
      #
      # The concern is a no-op if no channel matches — callers fall back to
      # +Spree::Current.channel+'s store-default behavior.
      module ChannelResolution
        extend ActiveSupport::Concern

        CHANNEL_HEADER = 'X-Spree-Channel'.freeze

        included do
          before_action :set_current_channel
        end

        protected

        def current_channel
          @current_channel ||= channel_from_header || Spree::Current.channel
        end

        private

        # Only write to Spree::Current when the header resolves a specific
        # channel. The store-default fallback is handled lazily by
        # +Spree::Current.channel+ itself, which avoids one query per
        # header-less API request.
        def set_current_channel
          channel = channel_from_header
          Spree::Current.channel = channel if channel
        end

        def channel_from_header
          code = request.headers[CHANNEL_HEADER].presence
          return nil if code.blank?
          return nil unless current_store

          current_store.channels.active.find_by(code: code)
        end
      end
    end
  end
end
