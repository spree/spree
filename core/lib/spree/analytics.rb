module Spree
  module Analytics
    def self.events
      @@supported_events ||= Spree.analytics.events
    end

    def self.event_handlers
      @@event_handlers ||= Spree.analytics.handlers
    end
  end
end
