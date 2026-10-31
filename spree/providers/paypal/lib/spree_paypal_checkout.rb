require 'paypal_server_sdk'
require 'spree_core'
require 'spree_paypal_checkout/engine'

module SpreePaypalCheckout
  # Background queue for the gem's jobs. Defaults to Spree's default queue.
  def self.queue
    @queue ||= Spree.queues.default
  end

  class << self
    attr_writer :queue
  end
end
