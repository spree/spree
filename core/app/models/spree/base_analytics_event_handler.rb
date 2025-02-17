module Spree
  class BaseAnalyticsEventHandler
    SUPPORTED_EVENTS = {
      product_viewed: 'Product Viewed',
      product_list_viewed: 'Product List Viewed',
      product_searched: 'Product Searched',
      product_added: 'Product Added',
      product_removed: 'Product Removed',

      payment_info_entered: 'Payment Info Entered',
      coupon_entered: 'Coupon Entered',
      coupon_removed: 'Coupon Removed',
      coupon_applied: 'Coupon Applied',
      coupon_denied: 'Coupon Denied',

      checkout_started: 'Checkout Started',
      checkout_email_entered: 'Checkout Email Entered',
      checkout_step_viewed: 'Checkout Step Viewed',
      checkout_step_completed: 'Checkout Step Completed',

      order_completed: 'Order Completed',
      order_cancelled: 'Order Cancelled',
      order_refunded: 'Order Refunded',
      package_shipped: 'Package Shipped',
      order_fulfilled: 'Order Fulfilled',

      gift_card_issued: 'Gift Card Issued'
    }.freeze

    # Initializes the event handler
    # @param client [Object] The client object
    # @param opts [Hash] The options
    # @option opts [User] :user
    # @option opts [String] :session_id
    def initialize(client, opts = {})
      @client = client
      @user = opts[:user]
      @session_id = opts[:session_id]
    end

    attr_reader :client, :user, :session_id

    # Handles the event
    # @param event_name [String] eg. 'order_completed'
    # @param properties [Hash] eg. { product: Spree::Product, taxon: Spree::Taxon, query: String }
    # rubocop:disable Lint/UnusedMethodArgument
    def handle(event_name, properties = {})
      raise NotImplementedError, 'Subclasses must implement the handle method'
    end
    # rubocop:enable Lint/UnusedMethodArgument

    # Returns the label for the event
    # @param event_name [String] eg. 'order_completed'
    # @return [String] eg. 'Order Completed'
    def event_label(event_name)
      SUPPORTED_EVENTS[event_name]
    end

    protected

    # Returns the identity hash for the event
    # @return [Hash] eg. { user_id: 1, session_id: '123' }
    def identity_hash
      {
        user_id: user&.id,
        session_id: session_id
      }
    end
  end
end
