require 'avatax'
require 'spree_core'
require 'spree_avalara/engine'

module SpreeAvalara
  # Stamped on every Spree::TaxLine this gem writes, and the value it scopes its
  # own rows by when it sweeps them. Also what the Integration's wire shorthand
  # derives to, so the two can never drift apart.
  PROVIDER_ID = 'avalara'.freeze

  # Avalara's identifier for the certified Spree extension. Issued by Avalara to
  # the integration rather than chosen by it: it travels in the X-Avalara-Client
  # header and is how Avalara attributes calls to this extension. Despite the
  # name it is not a display string — renaming it detaches the gem from that
  # certification.
  APP_NAME = 'a0o0b000005HsXPAA0'.freeze
  APP_VERSION = 'Spree by Spark'.freeze

  # Deployment configuration rather than merchant preferences: how long a
  # checkout waits on Avalara is an infrastructure decision, and an estimate runs
  # inside the cart's own transaction, so a slow response holds a lock.
  DEFAULT_OPEN_TIMEOUT = 2.0
  DEFAULT_READ_TIMEOUT = 6.0

  class Error < StandardError; end

  # Raised when a store has no active Avalara integration but its market points
  # at this provider. Tax calculation fails closed, so this surfaces rather than
  # letting an order be placed with no tax at all.
  class NotConfiguredError < Error; end

  # An AvaTax call that did not succeed, carrying the HTTP status and Avalara's
  # own parsed error payload so callers can tell a duplicate document from a
  # rejected credential without re-reading the response.
  class RequestError < Error
    attr_reader :status, :details

    # @param message [String, nil]
    # @param status [Integer, nil] the HTTP status, nil for a transport failure
    # @param details [Hash, nil] Avalara's `error` object, parsed
    def initialize(message = nil, status: nil, details: nil)
      @status = status
      @details = details

      super(message)
    end
  end

  # @return [Float] seconds to wait for a connection to Avalara
  def self.open_timeout
    Float(ENV.fetch('SPREE_AVALARA_OPEN_TIMEOUT', DEFAULT_OPEN_TIMEOUT))
  end

  # @return [Float] seconds to wait for Avalara's response
  def self.read_timeout
    Float(ENV.fetch('SPREE_AVALARA_READ_TIMEOUT', DEFAULT_READ_TIMEOUT))
  end
end
