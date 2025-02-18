module Spree
  class BaseAnalyticsEventHandler
    # Initializes the event handler
    # @param client [Object] The client object
    # @param opts [Hash] The options
    # @option opts [User] :user
    # @option opts [String] :session_id
    def initialize(opts = {})
      @user = opts[:user]
      @session = opts[:session]
      @request = opts[:request]
    end

    attr_reader :user, :session, :request

    # Returns the client
    # @return [Object] The client object
    def client
      raise NotImplementedError, 'Subclasses must implement the client method'
    end

    # Handles the event
    # @param event_name [String] eg. 'order_completed'
    # @param properties [Hash] eg. { product: Spree::Product, taxon: Spree::Taxon, query: String }
    # rubocop:disable Lint/UnusedMethodArgument
    def handle_event(event_name, properties = {})
      raise NotImplementedError, 'Subclasses must implement the handle method'
    end
    # rubocop:enable Lint/UnusedMethodArgument

    # Returns the human name for the event
    # @param event_name [String] eg. 'order_completed'
    # @return [String] eg. 'Order Completed'
    def event_human_name(event_name)
      Analytics.events[event_name.to_sym]
    end

    protected

    # Returns the identity hash for the event
    # @return [Hash] eg. { user_id: 1, session_id: '123' }
    def identity_hash
      {
        user_id: user&.id,
        session_id: session&.id
      }
    end
  end
end
