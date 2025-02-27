module Spree
  module Analytics
    def self.events
      @@supported_events ||= Rails.application.config.spree.analytics_events
    end

    def self.event_handlers
      @@event_handlers ||= Rails.application.config.spree.analytics_event_handlers
    end
  end
end
