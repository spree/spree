require 'rexml/document'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:

    class EfsnetGateway < Gateway
      self.supported_countries = ['US']
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      self.homepage_url = 'http://www.concordefsnet.com/'
      self.display_name = 'Efsnet'
     
      TEST_URL = 'https://testefsnet.concordebiz.com/efsnet.dll'
      LIVE_URL = 'https://efsnet.concordebiz.com/efsnet.dll'
      
      # login is your Store ID
      # password is your Store Key
      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options
        super      
      end
      
      def test?
        @options[:test] || super
      end
      
      def authorize(money, creditcard, options = {})
        request = build_credit_card_request(money, creditcard, options)
        commit(:credit_card_authorize, request)
      end

      def purchase(money, creditcard, options = {})
        request = build_credit_card_request(money, creditcard, options)
        commit(:credit_card_charge, request)
      end
     
      def capture(money, identification, options = {})
        request = build_refund_or_settle_request(money, identification, options)
        commit(:credit_card_settle, request)
      end

      def credit(money, identification_or_credit_card, options = {})
        if identification_or_credit_card.is_a?(String)
          # Perform authorization reversal
          request = build_refund_or_settle_request(money, identification_or_credit_card, options)
          commit(:credit_card_refund, request)
        else
          # Perform credit
          request = build_credit_card_request(money, identification_or_credit_card, options)
          commit(:credit_card_credit, request)
        end
      end

      def void(identification, options = {})
        requires!(options, :order_id)
        original_transaction_id, original_transaction_amount = identification.split(";")
        commit(:void_transaction, {:reference_number => format_reference_number(options[:order_id]), :transaction_ID => original_transaction_id})
      end
      
      def voice_authorize(money, authorization_code, creditcard, options = {})
        options[:authorization_number] = authorization_code
        request = build_credit_card_request(money, creditcard, options)
        commit(:credit_card_voice_authorize, request)
      end
      
      def force(money, authorization_code, creditcard, options = {})
        options[:authorization_number] = authorization_code
        request = build_credit_card_request(money, creditcard, options)
        commit(:credit_card_capture, request)
      end
      
      def system_check
        commit(:system_check, {})      
      end

      private

      def build_refund_or_settle_request(money, identification, options = {})
        original_transaction_id, original_transaction_amount = identification.split(";")
        
        requires!(options, :order_id)

        post = {
          :reference_number => format_reference_number(options[:order_id]),
          :transaction_amount => amount(money),
          :original_transaction_amount => original_transaction_amount,
          :original_transaction_ID => original_transaction_id,
          :client_ip_address => options[:ip]
        }
      end
    
      def build_credit_card_request(money, creditcard, options = {})
        requires!(options, :order_id)

        post = {
          :reference_number => format_reference_number(options[:order_id]),
          :authorization_number => options[:authorization_number],
          :transaction_amount => amount(money),
          :client_ip_address => options[:ip]
          
        }
        add_creditcard(post,creditcard)
        add_address(post,options)
        post
      end
      
      def format_reference_number(number)
        number.to_s.slice(0,12)
      end
    
      def add_address(post,options)
        if address = options[:billing_address] || options[:address]
          if address[:address2]
            post[:billing_address]    = address[:address1].to_s << ' ' <<  address[:address2].to_s
          else
            post[:billing_address]    = address[:address1].to_s
          end
          post[:billing_city]         = address[:city].to_s
          post[:billing_state]        = address[:state].blank?  ? 'n/a' : address[:state]
          post[:billing_postal_code]  = address[:zip].to_s       
          post[:billing_country]      = address[:country].to_s
        end

        if address = options[:shipping_address]
          if address[:address2]
            post[:shipping_address]   = address[:address1].to_s << ' ' <<  address[:address2].to_s
          else
            post[:shipping_address]   = address[:address1].to_s
          end
          post[:shipping_city]        = address[:city].to_s
          post[:shipping_state]       = address[:state].blank?  ? 'n/a' : address[:state]
          post[:shipping_postal_code] = address[:zip].to_s       
          post[:shipping_country]     = address[:country].to_s
        end
      end

      def add_creditcard(post, creditcard)      
        post[:billing_name]  = creditcard.name if creditcard.name
        post[:account_number]  = creditcard.number
        post[:card_verification_value] = creditcard.verification_value if creditcard.verification_value?
        post[:expiration_month]  = sprintf("%.2i", creditcard.month)
        post[:expiration_year]  = sprintf("%.4i", creditcard.year)[-2..-1]
      end

  
      def commit(action, parameters)  
        response = parse(ssl_post(test? ? TEST_URL : LIVE_URL, post_data(action, parameters), 'Content-Type' => 'text/xml'))

        Response.new(success?(response), message_from(response[:result_message]), response,
          :test => test?,
          :authorization => authorization_from(response, parameters),
          :avs_result => { :code => response[:avs_response_code] },
          :cvv_result => response[:cvv_response_code]
        )
      end
      
      def success?(response)
        response[:response_code] == '0'
      end
      
      def authorization_from(response, params)
        [ response[:transaction_id], params[:transaction_amount] ].compact.join(';')
      end
                                               
      def parse(xml)
        response = {}

        xml = REXML::Document.new(xml)          

        xml.elements.each('//Reply//TransactionReply/*') do |node|

          response[node.name.underscore.to_sym] = normalize(node.text)

        end unless xml.root.nil?

        response
      end     

      def post_data(action, parameters = {})
        xml   = REXML::Document.new("<?xml version='1.0' encoding='UTF-8'?>")
        root  = xml.add_element("Request")
        root.attributes["StoreID"] = options[:login]
        root.attributes["StoreKey"] = options[:password]
        root.attributes["ApplicationID"] = 'ot 1.0'
        transaction = root.add_element(action.to_s.camelize)

        actions[action].each do |key|
          transaction.add_element(key.to_s.camelize).text = parameters[key] unless parameters[key].blank?
        end

        xml.to_s
      end
    
      def message_from(message)
        return 'Unspecified error' if message.blank?
        message.gsub(/[^\w]/, ' ').split.join(" ").capitalize
      end

      # Make a ruby type out of the response string
      def normalize(field)
        case field
        when "true"   then true
        when "false"  then false
        when ""       then nil
        when "null"   then nil
        else field
        end        
      end         
    
      def actions
        ACTIONS
      end

      CREDIT_CARD_FIELDS =  [:authorization_number, :client_ip_address, :billing_address, :billing_city, :billing_state, :billing_postal_code, :billing_country, :billing_name, :card_verification_value, :expiration_month, :expiration_year, :reference_number, :transaction_amount, :account_number ]

      ACTIONS = {
           :credit_card_authorize		=> CREDIT_CARD_FIELDS,
           :credit_card_charge			=> CREDIT_CARD_FIELDS,
           :credit_card_voice_authorize		=> CREDIT_CARD_FIELDS,
           :credit_card_capture			=> CREDIT_CARD_FIELDS,
           :credit_card_credit			=> CREDIT_CARD_FIELDS << :original_transaction_amount,
           :credit_card_refund			=> [:reference_number, :transaction_amount, :original_transaction_amount, :original_transaction_ID, :client_ip_address],
           :void_transaction			=> [:reference_number, :transaction_ID],
           :credit_card_settle			=> [:reference_number, :transaction_amount, :original_transaction_amount, :original_transaction_ID, :client_ip_address],
           :system_check			=> [:system_check],
      }    
    end
  end
end
