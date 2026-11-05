require 'spree_core'
# After Rails: the SDK builds its default configuration on require, reading Rails.logger.
require 'klaviyo-api-sdk'
require 'spree_klaviyo/engine'

module SpreeKlaviyo
  # Background queue for the gem's jobs. Defaults to Spree's default queue.
  def self.queue
    @queue ||= Spree.queues.default
  end

  class << self
    attr_writer :queue
  end
end
