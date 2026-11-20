require 'adyen-ruby-api-library'
require 'spree_core'
require 'spree_adyen/engine'

module SpreeAdyen
  # Background queue for the gem's jobs. Defaults to Spree's default queue.
  def self.queue
    @queue ||= Spree.queues.default
  end

  class << self
    attr_writer :queue
  end
end
