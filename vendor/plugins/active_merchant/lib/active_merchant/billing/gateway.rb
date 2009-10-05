require 'net/http'
require 'net/https'
require 'active_merchant/billing/response'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # 
    # == Description
    # The Gateway class is the base class for all ActiveMerchant gateway implementations. 
    # 
    # The standard list of gateway functions that most concrete gateway subclasses implement is:
    # 
    # * <tt>purchase(money, creditcard, options = {})</tt>
    # * <tt>authorize(money, creditcard, options = {})</tt>
    # * <tt>capture(money, authorization, options = {})</tt>
    # * <tt>void(identification, options = {})</tt>
    # * <tt>credit(money, identification, options = {})</tt>
    #
    # Some gateways include features for recurring billing
    #
    # * <tt>recurring(money, creditcard, options = {})</tt>
    #
    # Some gateways also support features for storing credit cards:
    #
    # * <tt>store(creditcard, options = {})</tt>
    # * <tt>unstore(identification, options = {})</tt>
    # 
    # === Gateway Options
    # The options hash consists of the following options:
    #
    # * <tt>:order_id</tt> - The order number
    # * <tt>:ip</tt> - The IP address of the customer making the purchase
    # * <tt>:customer</tt> - The name, customer number, or other information that identifies the customer
    # * <tt>:invoice</tt> - The invoice number
    # * <tt>:merchant</tt> - The name or description of the merchant offering the product
    # * <tt>:description</tt> - A description of the transaction
    # * <tt>:email</tt> - The email address of the customer
    # * <tt>:currency</tt> - The currency of the transaction.  Only important when you are using a currency that is not the default with a gateway that supports multiple currencies.
    # * <tt>:billing_address</tt> - A hash containing the billing address of the customer.
    # * <tt>:shipping_address</tt> - A hash containing the shipping address of the customer.
    # 
    # The <tt>:billing_address</tt>, and <tt>:shipping_address</tt> hashes can have the following keys:
    # 
    # * <tt>:name</tt> - The full name of the customer.
    # * <tt>:company</tt> - The company name of the customer.
    # * <tt>:address1</tt> - The primary street address of the customer.
    # * <tt>:address2</tt> - Additional line of address information.
    # * <tt>:city</tt> - The city of the customer.
    # * <tt>:state</tt> - The state of the customer.  The 2 digit code for US and Canadian addresses. The full name of the state or province for foreign addresses.
    # * <tt>:country</tt> - The [ISO 3166-1-alpha-2 code](http://www.iso.org/iso/country_codes/iso_3166_code_lists/english_country_names_and_code_elements.htm) for the customer.
    # * <tt>:zip</tt> - The zip or postal code of the customer.
    # * <tt>:phone</tt> - The phone number of the customer.
    #
    # == Implmenting new gateways
    #
    # See the {ActiveMerchant Guide to Contributing}[http://code.google.com/p/activemerchant/wiki/Contributing]
    #
    class Gateway
      include PostsData
      include RequiresParameters
      include CreditCardFormatting
      include Utils
      
      DEBIT_CARDS = [ :switch, :solo ]
      
      cattr_reader :implementations
      @@implementations = []
      
      def self.inherited(subclass)
        super
        @@implementations << subclass
      end
    
      # The format of the amounts used by the gateway
      # :dollars => '12.50'
      # :cents => '1250'
      class_inheritable_accessor :money_format
      self.money_format = :dollars
      
      # The default currency for the transactions if no currency is provided
      class_inheritable_accessor :default_currency
      
      # The countries of merchants the gateway supports
      class_inheritable_accessor :supported_countries
      self.supported_countries = []
      
      # The supported card types for the gateway
      class_inheritable_accessor :supported_cardtypes
      self.supported_cardtypes = []
      
      class_inheritable_accessor :homepage_url
      class_inheritable_accessor :display_name
      
      # The application making the calls to the gateway
      # Useful for things like the PayPal build notation (BN) id fields
      superclass_delegating_accessor :application_id
      self.application_id = 'ActiveMerchant'
      
      attr_reader :options
      
      # Use this method to check if your gateway of interest supports a credit card of some type
      def self.supports?(card_type)
        supported_cardtypes.include?(card_type.to_sym)
      end
      
      def self.card_brand(source)
        result = source.respond_to?(:brand) ? source.brand : source.type
        result.to_s.downcase
      end
    
      def card_brand(source)
        self.class.card_brand(source)
      end
    
      # Initialize a new gateway.
      # 
      # See the documentation for the gateway you will be using to make sure there are no other 
      # required options.
      def initialize(options = {})
      end
                                     
      # Are we running in test mode?
      def test?
        Base.gateway_mode == :test
      end
            
      private # :nodoc: all

      def name 
        self.class.name.scan(/\:\:(\w+)Gateway/).flatten.first
      end
      
      def amount(money)
        return nil if money.nil?
        cents = money.respond_to?(:cents) ? money.cents : money 

        if money.is_a?(String) or cents.to_i < 0
          raise ArgumentError, 'money amount must be either a Money object or a positive integer in cents.' 
        end

        if self.money_format == :cents
          cents.to_s
        else
          sprintf("%.2f", cents.to_f / 100)
        end
      end
      
      def currency(money)
        money.respond_to?(:currency) ? money.currency : self.default_currency
      end
      
      def requires_start_date_or_issue_number?(credit_card)
        return false if card_brand(credit_card).blank?
        DEBIT_CARDS.include?(card_brand(credit_card).to_sym)
      end
    end
  end
end
