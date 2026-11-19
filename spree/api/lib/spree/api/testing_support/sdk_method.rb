module Spree
  module Api
    module TestingSupport
      # rswag helper for what an operation is called in the SDK client
      # `spree sdk generate` writes for an extension. By default a method is
      # named after the path (`PATCH /quotes/{id}/send` → `quotes.send`), and
      # an `operationId` renames it, but the `operationId` also names the
      # operation's agent tool. This names the SDK method alone:
      #
      #   delete 'Remove a file from a quote' do
      #     sdk_method :remove_attachment                    # quotes.removeAttachment
      #   end
      #
      #   post 'Upload a file for a quote request' do
      #     sdk_method :presign_attachment, namespace: :quotes  # not carts.…
      #   end
      #
      # See docs/plans/6.0-sdk-extensions.md.
      module SdkMethod
        METHOD_KEY = :'x-spree-sdk-method'
        NAMESPACE_KEY = :'x-spree-sdk-namespace'

        # @param name [Symbol, String] the method, snake_case or camelCase
        # @param namespace [Symbol, String, nil] the client namespace it goes in,
        #   instead of the path's resource
        # @return [void]
        def sdk_method(name, namespace: nil)
          metadata[:operation][METHOD_KEY] = name.to_s
          metadata[:operation][NAMESPACE_KEY] = namespace.to_s if namespace
        end
      end
    end
  end
end
