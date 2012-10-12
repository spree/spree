module Spree
  class StoreController < Spree::BaseController
    include Spree::Core::ControllerHelpers::Order

    # Convenience method for firing instrumentation events with the default payload hash
    def fire_event(name, extra_payload = {})
      ActiveSupport::Notifications.instrument(name, default_notification_payload.merge(extra_payload))
    end

    # Creates the hash that is sent as the payload for all notifications. Specific notifications will
    # add additional keys as appropriate. Override this method if you need additional data when
    # responding to a notification
    def default_notification_payload
      {:user => try_spree_current_user, :order => current_order}
    end
  end
end

