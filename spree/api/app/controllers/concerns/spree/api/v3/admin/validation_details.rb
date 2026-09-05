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
                code = detail[:error] if detail[:error].is_a?(Symbol)

                # Interpolation values first, so the keys below are the ones
                # this formatter computed: a validation may itself carry a
                # `code:` option, and it must not displace the Rails error.
                detail.except(:error).merge(
                  code: code,
                  message: message,
                  specific: code.present? && specific_message?(errors, attribute, code, message)
                )
              end
            end
          end

          # Whether `message` says more than its `code` alone would.
          #
          # A code like `:invalid` is generic, and a client holding its own
          # translation of that code should prefer it. But a model may override
          # the message for the same code with something far more useful — the
          # webhook URL validation reports `:invalid` and answers "must be a
          # valid http or https URL". Replacing that with a translated "is
          # invalid" loses what the merchant needs.
          #
          # Only the server can tell the two apart: the comparison is against
          # the code's default *in the request's locale*, so it holds for a
          # store trading in any language. A client cannot do it — it would
          # have to recognise the default wording in every locale it supports.
          #
          # @return [Boolean] true when the model supplied its own wording
          def specific_message?(errors, attribute, code, message)
            message != errors.generate_message(attribute, code)
          rescue StandardError
            # An unknown code has no default to compare against; treat the
            # message as the code's own so the client may translate it.
            false
          end
        end
      end
    end
  end
end
