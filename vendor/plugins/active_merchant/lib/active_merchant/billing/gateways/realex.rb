require 'rexml/document'
require 'digest/sha1'

module ActiveMerchant
  module Billing
    # Realex us the leading CC gateway in Ireland
    # see http://www.realexpayments.com
    # Contributed by John Ward (john@ward.name)
    # see http://thinedgeofthewedge.blogspot.com
    # 
    # Realex works using the following
    # login - The unique id of the merchant
    # password - The secret is used to digitally sign the request
    # account - This is an optional third part of the authentication process
    # and is used if the merchant wishes do distuinguish cc traffic from the different sources
    # by using a different account. This must be created in advance
    #
    # the Realex team decided to make the orderid unique per request, 
    # so if validation fails you can not correct and resend using the 
    # same order id
    class RealexGateway < Gateway
      URL = 'https://epage.payandshop.com/epage-remote.cgi'
                  
      CARD_MAPPING = {
        'master'            => 'MC',
        'visa'              => 'VISA',
        'american_express'  => 'AMEX',
        'diners_club'       => 'DINERS',
        'switch'            => 'SWITCH',
        'solo'              => 'SWITCH',
        'laser'             => 'LASER'
      }
      
      self.money_format = :cents
      self.default_currency = 'EUR'
      self.supported_cardtypes = [ :visa, :master, :american_express, :diners_club, :switch, :solo, :laser ]
      self.supported_countries = [ 'IE', 'GB' ]
      self.homepage_url = 'http://www.realexpayments.com/'
      self.display_name = 'Realex'
           
      SUCCESS, DECLINED          = "Successful", "Declined"
      BANK_ERROR = REALEX_ERROR  = "Gateway is in maintenance. Please try again later."
      ERROR = CLIENT_DEACTIVATED = "Gateway Error"
      
      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options
        super
      end  
  
      def purchase(money, credit_card, options = {})
        requires!(options, :order_id)
        
        request = build_purchase_or_authorization_request(:purchase, money, credit_card, options) 
        commit(request)
      end     
      
      private           
      def commit(request)        
        response = parse(ssl_post(URL, request))

        Response.new(response[:result] == "00", message_from(response), response,
          :test => response[:message] =~ /\[ test system \]/,
          :authorization => response[:authcode],
          :cvv_result => response[:cvnresult]
        )      
      end

      def parse(xml)
        response = {}
        
        xml = REXML::Document.new(xml)          
        xml.elements.each('//response/*') do |node|

          if (node.elements.size == 0)
            response[node.name.downcase.to_sym] = normalize(node.text)
          else
            node.elements.each do |childnode|
              name = "#{node.name.downcase}_#{childnode.name.downcase}"
              response[name.to_sym] = normalize(childnode.text)
            end              
          end

        end unless xml.root.nil?

        response
      end
      
      def parse_credit_card_number(request)
        xml = REXML::Document.new(request)
        card_number = REXML::XPath.first(xml, '/request/card/number')
        card_number && card_number.text
      end

      def build_purchase_or_authorization_request(action, money, credit_card, options)
        timestamp = Time.now.strftime('%Y%m%d%H%M%S')
        
        xml = Builder::XmlMarkup.new :indent => 2
        xml.tag! 'request', 'timestamp' => timestamp, 'type' => 'auth' do
      
          xml.tag! 'merchantid', @options[:login] 
          xml.tag! 'account', @options[:account]
      
          xml.tag! 'orderid', sanitize_order_id(options[:order_id])
          xml.tag! 'amount', amount(money), 'currency' => options[:currency] || currency(money)

          xml.tag! 'card' do
            xml.tag! 'number', credit_card.number
            xml.tag! 'expdate', expiry_date(credit_card)
            xml.tag! 'type', CARD_MAPPING[card_brand(credit_card).to_s]
            xml.tag! 'chname', credit_card.name
            xml.tag! 'issueno', credit_card.issue_number
            
            xml.tag! 'cvn' do
              xml.tag! 'number', credit_card.verification_value
              xml.tag! 'presind', credit_card.verification_value? ? 1 : nil
            end
          end
          
          xml.tag! 'autosettle', 'flag' => auto_settle_flag(action)
          xml.tag! 'sha1hash', sha1from("#{timestamp}.#{@options[:login]}.#{sanitize_order_id(options[:order_id])}.#{amount(money)}.#{options[:currency] || currency(money)}.#{credit_card.number}")
          xml.tag! 'comments' do
            xml.tag! 'comment', options[:description], 'id' => 1 
            xml.tag! 'comment', 'id' => 2
          end
          
          billing_address = options[:billing_address] || options[:address] || {}
          shipping_address = options[:shipping_address] || {}
          
          xml.tag! 'tssinfo' do
            xml.tag! 'address', 'type' => 'billing' do
              xml.tag! 'code', billing_address[:zip]
              xml.tag! 'country', billing_address[:country]
            end

            xml.tag! 'address', 'type' => 'shipping' do
              xml.tag! 'code', shipping_address[:zip]
              xml.tag! 'country', shipping_address[:country]
            end
            
            xml.tag! 'custnum', options[:customer]
            
            xml.tag! 'prodid', options[:invoice]
            xml.tag! 'varref'
          end
        end

        xml.target!
      end
      
      def auto_settle_flag(action)
        action == :authorization ? '0' : '1'
      end
      
      def expiry_date(credit_card)
        "#{format(credit_card.month, :two_digits)}#{format(credit_card.year, :two_digits)}"
      end
      
      def sha1from(string)
        Digest::SHA1.hexdigest("#{Digest::SHA1.hexdigest(string)}.#{@options[:password]}")
      end
      
      def normalize(field)
        case field
        when "true"   then true
        when "false"  then false
        when ""       then nil
        when "null"   then nil
        else field
        end        
      end
      
      def message_from(response)
        message = nil
        case response[:result]                
        when "00"
          message = SUCCESS
        when "101"
          message = response[:message]
        when "102", "103"
          message = DECLINED
        when /^2[0-9][0-9]/
          message = BANK_ERROR
        when /^3[0-9][0-9]/
          message = REALEX_ERROR
        when /^5[0-9][0-9]/
          message = ERROR
        when "666"
          message = CLIENT_DEACTIVATED
        else
          message = DECLINED
        end  
      end
      
      def sanitize_order_id(order_id)
        order_id.to_s.gsub(/[^a-zA-Z0-9\-_]/, '')
      end
    end
  end
end