module Spree
  # The dashboard chat assistant (docs/plans/6.0-dashboard-assistant.md).
  #
  # Optional: without an active AI integration on the store, nothing here runs
  # and the dashboard hides the panel.
  module Assistant
    # Written as a tool call's result when a mutation is held for approval.
    # Replaced with the real outcome once a merchant decides, so it is never
    # what the model finally reads.
    AWAITING_APPROVAL_MARKER = 'AWAITING_MERCHANT_APPROVAL'.freeze

    # Claude, always, unless a merchant picks otherwise.
    DEFAULT_PROVIDER_KEY = 'anthropic'.freeze

    # The conversation could not run at all — no vendor connected, or the vendor
    # refused. Surfaced to the merchant rather than swallowed.
    class ProviderError < StandardError
    end

    # A tool call was approved twice, or resolved after it had already been
    # decided.
    class AlreadyResolvedError < StandardError
    end

    # The approving admin no longer holds the permission the tool needs.
    class ForbiddenError < StandardError
    end

    # A held call names a tool that is no longer registered.
    class UnknownToolError < StandardError
    end

    # Registries live in this gem's own config namespace rather than core's
    # `Spree::Environment` struct: core must not grow a member for an optional
    # gem, and the accessors below keep the calling convention identical to
    # `Spree.tax_providers`.
    Environment = Struct.new(:providers)

    class << self
      # AI vendors the assistant can run on. Registered like tax or
      # delivery-rate providers, so a host app or extension appends its own.
      #
      # @return [Array<Class>]
      delegate :providers, to: :config

      delegate :providers=, to: :config

      # @return [Spree::Assistant::Environment]
      def config
        Rails.application.config.spree_assistant
      end
    end
  end

  class << self
    # @return [Array<Class>] AI vendors the assistant can run on
    def assistant_providers
      Spree::Assistant.providers
    end

    def assistant_providers=(value)
      Spree::Assistant.providers = value
    end
  end
end
