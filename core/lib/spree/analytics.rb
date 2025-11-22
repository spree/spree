module Spree
  module Analytics
    def self.events
      @@supported_events ||= Spree.analytics_events
    end

    def self.event_handlers
      @@event_handlers ||= Spree.analytics_event_handlers
    end
  end
end
