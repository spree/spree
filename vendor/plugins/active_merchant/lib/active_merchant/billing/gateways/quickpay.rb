require 'rexml/document'
require 'digest/md5'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class QuickpayGateway < Gateway
      URL = 'https://secure.quickpay.dk/transaction.php'

      self.default_currency = 'DKK'  
      self.money_format = :cents
      self.supported_cardtypes = [ :dankort, :forbrugsforeningen, :visa, :master, :american_express, :diners_club, :jcb, :maestro ]
      self.supported_countries = ['DK']
      self.homepage_url = 'http://quickpay.dk/'
      self.display_name = 'Quickpay'
      
      TRANSACTIONS = {
        :authorization => '1100',
        :capture       => '1220',
        :void          => '1420',
        :credit        => 'credit'
      }
      
      POS_CODES = {
        :mail               => '100020100110',
        :phone              => '100030100110',
        :internet           => 'L00500L00130',
        :internet_secure    => 'K00500K00130',
        :internet_edankort  => 'KM0500R00130',
        :internet_recurring => 'K00540K00130' 
      }
      
      MD5_CHECK_FIELDS = {
        :authorization    => [:msgtype, :cardnumber, :amount, :expirationdate, :posc, :ordernum, :currency, :cvd, :merchant, :authtype, :reference, :transaction],
        :capture => [:msgtype, :amount, :merchant, :transaction],
        :void    => [:msgtype, :merchant, :transaction],
        :credit  => [:msgtype, :amount, :merchant, :transaction]
      }
      
      CURRENCIES = [ 'DKK', 'EUR', 'NOK', 'GBP', 'USD' ]
      
      APPROVED = '000'
      
      # The login is the QuickpayId
      # The password is the md5checkword from the Quickpay admin interface
      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options
        super
      end  
      
      def authorize(money, creditcard, options = {})
        post = {}
        
        add_amount(post, money, options)
        add_creditcard(post, creditcard)        
        add_invoice(post, options)

        commit(:authorization, post)
      end
      
      def purchase(money, creditcard, options = {})
        auth = authorize(money, creditcard, options)
        auth.success? ? capture(money, auth.authorization) : auth
      end                       
    
      def capture(money, authorization, options = {})
        post = {}
        
        add_reference(post, authorization)
        add_amount(post, money)
        
        commit(:capture, post)
      end
      
      def void(identification, options = {})
        post = {}
        
        add_reference(post, identification)
        
        commit(:void, post)
      end
      
      def credit(money, identification, options = {})
        post = {}
        
        add_amount(post, money)
        add_reference(post, identification)
        
        commit(:credit, post)
      end
    
      private                       
  
      def add_amount(post, money, options = {})
        post[:amount]   = amount(money)
        post[:currency] = options[:currency] || currency(money)
      end
      
      def add_invoice(post, options)
        post[:ordernum] = format_order_number(options[:order_id])
        post[:posc]   = POS_CODES[:internet_secure]
      end
      
      def add_creditcard(post, credit_card)
        post[:cardnumber]     = credit_card.number   
        post[:cvd]            = credit_card.verification_value
        post[:expirationdate] = expdate(credit_card) 
      end
      
      def add_reference(post, identification)
        post[:transaction] = identification
      end
      
      def commit(action, params)
        response = parse(ssl_post(URL, post_data(action, params)))
        
        Response.new(successful?(response), message_from(response), response, 
          :test => test?, 
          :authorization => response[:transaction]
        )
      end
      
      def successful?(response)
        response[:qpstat] == APPROVED
      end

      def parse(data)
        response = {}
        
        doc = REXML::Document.new(data)
        
        doc.root.attributes.each do |name, value|
          response[name.to_sym] = value
        end
        
        response
      end

      def message_from(response)
        case response[:qpstat]
        when '008'
          response[:qpstatmsg].to_s.scan(/[A-Z][a-z0-9 \/]+/).to_sentence
        else
          response[:qpstatmsg].to_s
        end
      end
      
      def post_data(action, params = {})
        params[:merchant]   = @options[:login]
        params[:msgtype]    = TRANSACTIONS[action]
        
        check_field = (action == :authorization) ? :md5checkV2 : :md5check
        params[check_field] = generate_check_hash(action, params)
        
        request = params.collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
        request
      end
  
      def generate_check_hash(action, params)
        string = MD5_CHECK_FIELDS[action].collect do |key|
          params[key]
        end.join('')
        
        # Add the md5checkword
        string << @options[:password].to_s
        
        Digest::MD5.hexdigest(string)
      end
      
      def expdate(credit_card)
        year  = format(credit_card.year, :two_digits)
        month = format(credit_card.month, :two_digits)

        "#{year}#{month}"
      end
      
      def format_order_number(number)
        number.to_s.gsub(/[^0-9]/, '').rjust(4, "0")
      end
    end
  end
end

