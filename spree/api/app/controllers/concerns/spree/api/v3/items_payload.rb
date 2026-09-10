module Spree
  module Api
    module V3
      # The `items` list a request names, for the endpoints that take one:
      # receiving a return, an exchange, a claim, a stock transfer or a
      # purchase order, and opening any of them.
      #
      # The distinction all of them need is between *omitted* and *empty*. An
      # omitted `items` means "all of it, as recorded" — receive the whole
      # return, the whole delivery. An empty list, or an explicit `null`, means
      # the caller named nothing, and must not fall through to that default.
      module ItemsPayload
        extend ActiveSupport::Concern

        # A payload whose `items` is not a list. Raised out of the params
        # helper so it cannot be mistaken for a workflow rejection, and
        # answered as the client mistake it is rather than a 500.
        class InvalidItems < StandardError; end

        included do
          rescue_from InvalidItems, with: :render_invalid_items
        end

        protected

        # @param keys [Array<Symbol>] the per-item keys to permit
        # @return [Array<ActionController::Parameters>, nil] nil when the
        #   payload said nothing about items
        def items_payload(keys)
          return nil unless params.key?(:items)

          raw = params[:items]
          return [] if raw.nil?
          # Checked before `permit`, which silently drops a scalar `items` —
          # leaving a client typo indistinguishable from "named nothing".
          raise InvalidItems unless raw.is_a?(Array)

          params.permit(items: keys)[:items] || []
        end

        # Reported against `:base`, not `:items`. The payload is malformed
        # rather than a field being wrong, and ActiveModel reads the named
        # attribute off the record to interpolate a message — which raises for
        # every record whose lines are not called `items` (a return's are
        # `return_line_items`).
        def render_invalid_items
          errors = ActiveModel::Errors.new(@resource || model_class.new)
          errors.add(:base, :invalid_items, message: Spree.t('errors.messages.items_not_a_list'))
          render_validation_error(errors)
        end
      end
    end
  end
end
