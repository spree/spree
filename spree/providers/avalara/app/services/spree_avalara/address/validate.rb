module SpreeAvalara
  module Address
    # Resolves an address against Avalara's validation service. Public so a
    # storefront can offer feedback at the address step; the checkout handler
    # uses the same service at completion.
    #
    # Avalara validates US and Canadian addresses only. Anything else resolves
    # trivially rather than failing — there is no opinion to be had.
    class Validate
      SUPPORTED_COUNTRIES = %w[US CA].freeze

      # The outcome, kept as a value object so callers read intent rather than
      # inspecting a response body.
      class Result
        include ActiveModel::Model
        include ActiveModel::Attributes

        attribute :body, default: -> { {} }
        attribute :error

        def success?
          error.nil?
        end
      end

      # Why an address was not accepted. `transport?` separates "Avalara says
      # this address is wrong" from "Avalara could not be reached", which the
      # two callers treat very differently.
      class Failure
        include ActiveModel::Model
        include ActiveModel::Attributes

        attribute :messages, default: -> { [] }
        attribute :transport, :boolean, default: false

        def transport?
          transport
        end

        def summary
          messages.compact_blank.join('; ').presence ||
            Spree.t('integrations.avalara.errors.address_unresolved')
        end
      end

      # @param address [Spree::Address, nil]
      # @param store [Spree::Store]
      # @return [Result]
      def call(address:, store:)
        return Result.new if address.nil? || !supported?(address)

        integration = Integration.active_for!(store)
        body = integration.client.resolve_address(AddressPresenter.new(address).call)
        messages = error_messages(body)

        return Result.new(body: body, error: Failure.new(messages: messages)) if messages.any?

        Result.new(body: body)
      rescue SpreeAvalara::RequestError => error
        # No status means nothing answered, which is Avalara being unreachable
        # rather than a judgement about the address.
        Result.new(error: Failure.new(messages: [error.message], transport: error.status.nil?))
      end

      private

      def supported?(address)
        SUPPORTED_COUNTRIES.include?(address.country_code.to_s.upcase)
      end

      # Avalara reports what it could not resolve in `messages`, and only
      # `Error`-severity entries mean the address is unusable — an
      # informational note about a corrected street name is not a refusal.
      def error_messages(body)
        Array(body['messages']).filter_map do |message|
          next unless message['severity'].to_s.casecmp?('error')

          message['summary'].presence || message['details'].presence
        end
      end
    end
  end
end
