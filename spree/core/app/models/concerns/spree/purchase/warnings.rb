module Spree
  module Purchase
    # Request-scoped messages for the buyer (an item removed, a delivery that
    # no longer fits), shared by Spree::Cart and Spree::Order. Never saved.
    module Warnings
      extend ActiveSupport::Concern

      included do
        attribute :warnings, default: -> { [] }
      end

      # The lock refuses unsaved attributes and reloads the record, which would
      # either fail or drop this request's warnings, so they are carried across
      # without counting as a change.
      def lock!(lock = true)
        return super unless persisted?

        existing_warnings = warnings
        clear_attribute_changes([:warnings])
        begin
          super
        ensure
          self.warnings = existing_warnings
          clear_attribute_changes([:warnings])
        end
      end
    end
  end
end
