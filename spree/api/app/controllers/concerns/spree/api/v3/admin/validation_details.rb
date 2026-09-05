module Spree
  module Api
    module V3
      module Admin
        # Richer validation details for the Admin API.
        #
        # The dashboard renders its own copy from its own locale files, so an
        # admin working in one language never reads a message resolved in the
        # store's. To let it do that, every entry carries the Rails error
        # `code` and the interpolation values that go with it; `message` stays
        # beside it as the fallback for clients without their own translation
        # (integrations, scripts, and the dashboard's own last resort).
        #
        # Store API responses keep the flat `{ attribute => [message] }` shape
        # — this override is deliberately not in the shared error handler.
        module ValidationDetails
          private

          # @param errors [ActiveModel::Errors]
          # @return [Hash{Symbol => Array<Hash>}] per-attribute error entries
          def format_validation_details(errors)
            errors.messages.each_with_object({}) do |(attribute, messages), result|
              # `details` and `messages` are populated in lockstep by
              # ActiveModel, so the nth message describes the nth detail. A
              # message added as a bare string has no symbol and reports a
              # nil code, which the dashboard reads as "render the message".
              details = errors.details[attribute] || []

              result[attribute] = messages.each_with_index.map do |message, index|
                detail = details[index] || {}
                # Interpolation values first, so `code` and `message` are the
                # ones this formatter computed: a validation may itself carry a
                # `code:` option, and it must not displace the Rails error.
                detail.except(:error).merge(
                  code: detail[:error].is_a?(Symbol) ? detail[:error] : nil,
                  message: message
                )
              end
            end
          end
        end
      end
    end
  end
end
