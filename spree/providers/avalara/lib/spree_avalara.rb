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
  # An AvaTax call that did not do what was asked — deliberately this gem's own
  # class and nothing of core's. Whether a given failure means "could not ask"
  # or "was told no" is a judgement about status codes, and TaxProvider makes it
  # at the contract boundary rather than the hierarchy making it here.
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

  # Whether prices for this sale include tax, resolved through the market that
  # covers the tax destination rather than read off the cart's own market.
  #
  # The two diverge for mundane reasons: a currency switch re-resolves the
  # market without consulting the address, a bill-address tax destination is
  # never checked against markets at all, and a request omitting the country
  # hint lands on the default market. Reading the browsing market naively is the
  # 5.x bug that spree_avatax_official#198 fixed; this restates that fix.
  #
  # Overridable on purpose — a host with its own notion of where a sale is
  # taxed replaces this one method.
  #
  # @param owner [Spree::Cart, Spree::Order]
  # @return [Boolean]
  def self.tax_inclusive?(owner)
    country = owner.tax_address&.country_code
    return owner.market&.tax_inclusive || false if country.blank?

    market = owner.market if owner.market&.country_codes&.include?(country)
    market ||= owner.store&.markets&.detect { |candidate| candidate.country_codes.include?(country) }

    (market || owner.market)&.tax_inclusive || false
  end

  # Where a sale ships from, which decides the origin jurisdiction. Avalara
  # refuses a document with no origin at all, and a cart has no fulfillment
  # until delivery is proposed — every recalculation before that would fail — so
  # the store's own default location stands in until one exists.
  #
  # Deliberately read-only: Store#default_stock_location creates a location when
  # the store has none, and pricing tax must not write inventory records.
  #
  # @param owner [Spree::Cart, Spree::Order]
  # @param item [Spree::LineItem, Spree::Fulfillment, Spree::Fee, nil]
  # @return [Spree::StockLocation, nil]
  def self.origin_location(owner, item: nil)
    from_item = case item
                when Spree::Fulfillment then item.stock_location
                when Spree::LineItem then item.fulfillments.first&.stock_location
                end
    return from_item if from_item

    locations = owner.store&.stock_locations&.first_party

    owner.fulfillments.first&.stock_location || locations&.find_by(default: true) || locations&.first
  end
end
