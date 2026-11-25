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
        # A validator records the rejected `value` as the model holds it: a raw
        # primary key for a foreign key, a class name for a type column, the
        # whole record when the validation names an association. An entry
        # reports each of those the way a client writes that attribute — a
        # prefixed id, a short type name — and leaves it out when there is no
        # such form.
        #
        # Store API responses keep the flat `{ attribute => [message] }` shape
        # — this override is deliberately not in the shared error handler.
        module ValidationDetails
          private

          # @param errors [ActiveModel::Errors]
          # @return [Hash{Symbol => Array<Hash>}] per-attribute error entries
          def format_validation_details(errors)
            errors.group_by_attribute.each_with_object({}) do |(attribute, attribute_errors), result|
              result[wire_error_attribute(errors, attribute)] = attribute_errors.map do |error|
                # A message added as a bare string has no symbol and reports a
                # nil code, which the dashboard reads as "render the message".
                code = error.raw_type.is_a?(Symbol) ? error.raw_type : nil
                message = error.message
                values = error.details.except(:error)

                # Interpolation values first, so the keys below are the ones
                # this formatter computed: a validation may itself carry a
                # `code:` option, and it must not displace the Rails error.
                wire_error_values(error, values).merge(
                  code: code,
                  message: message,
                  specific: code.present? && specific_message?(errors, attribute, code, message, values)
                )
              end
            end
          end

          def wire_error_values(error, values)
            # An error copied up from a nested record keeps the record and the
            # attribute it was raised on inside it.
            error = error.inner_error while error.respond_to?(:inner_error)

            values.each_with_object({}) do |(key, value), result|
              wire_value = wire_error_value(error.base, error.attribute.to_s, key, value)
              result[key] = wire_value unless wire_value.nil? && !value.nil?
            end
          end

          def wire_error_value(record, attribute, key, value)
            return wire_prefixed_id(value.class, value.id) if value.is_a?(ActiveRecord::Base)
            return value unless key == :value && value.present? && record.is_a?(ActiveRecord::Base)

            model = record.class
            attribute = model.attribute_aliases[attribute] || attribute
            references = model.reflect_on_all_associations(:belongs_to)

            if attribute == model.primary_key
              wire_prefixed_id(model, value)
            elsif attribute == model.inheritance_column
              model.try(:api_type_for, value)
            elsif (reference = references.find { |reflection| reflection.foreign_key.to_s == attribute })
              wire_prefixed_id(reference.polymorphic? ? record[reference.foreign_type].to_s.safe_constantize : reference.klass, value)
            elsif references.any? { |reflection| reflection.polymorphic? && reflection.foreign_type == attribute }
              Spree::Base.polymorphic_api_type(value)
            else
              value
            end
          end

          def wire_prefixed_id(model, id)
            model.prefixed_id_for(id) if model.try(:_prefix_id_prefix).present? && id.is_a?(Integer)
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
          # `raise: true` matters. Without it a code Rails has no default for
          # — every Spree code, whose copy lives under `spree.errors.messages`
          # — comes back as a "Translation missing" string, which differs from
          # the message and would mark every one of them as an override.
          #
          # The validation's own options come along: rebuilding the default for
          # `greater_than` without its `count` raises on the missing value.
          #
          # @return [Boolean] true when the model supplied its own wording
          def specific_message?(errors, attribute, code, message, options = {})
            message != errors.generate_message(attribute, code, **options.symbolize_keys, raise: true)
          rescue StandardError
            # Rebuilding the default can fail in several ordinary ways, and none
            # of them should turn a 422 into a 500:
            #
            # - `I18n::MissingTranslationData` — no Rails default at all, which
            #   is every Spree code.
            # - `I18n::MissingInterpolationArgument` — the default interpolates
            #   (`greater_than` wants `count`) but the call site passed only a
            #   `message:`, so the value was never recorded.
            # - `NoMethodError` — a nested attribute (`option_values.name`)
            #   names no method to read.
            #
            # In each case there is no default to compare against, so report no
            # override and let the client translate the code.
            false
          end
        end
      end
    end
  end
end
