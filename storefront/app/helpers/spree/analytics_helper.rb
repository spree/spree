module Spree
  module AnalyticsHelper
    def analytics_event_handlers
      @analytics_event_handlers ||= Spree::Analytics.event_handlers.map do |handler|
        handler.new(user: try_spree_current_user, session: session, request: request, store: Spree::Store.current, visitor_id: visitor_id)
      end
    end

    def track_event(event_name, record)
      return if current_theme_preview.present?
      return if unsupported_event?(event_name)

      analytics_event_handlers.each do |handler|
        handler.handle_event(event_name, record)
      end
    rescue => e
      Rails.error.report(
        e,
        context: { event_name: event_name, record: record },
        source: 'spree.storefront'
      )
    end

    def visitor_id
      session[:spree_visitor_token] ||= SecureRandom.uuid
    end

    def unsupported_event?(event_name)
      !Spree::Analytics.events.key?(event_name.to_sym)
    end
  end
end
