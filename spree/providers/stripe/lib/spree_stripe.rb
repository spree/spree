require 'stripe'
require 'spree_core'
require 'spree_stripe/engine'

module SpreeStripe
  # Background queue for the gem's jobs. Defaults to Spree's default queue.
  def self.queue
    @queue ||= Spree.queues.default
  end

  class << self
    attr_writer :queue
  end
end
