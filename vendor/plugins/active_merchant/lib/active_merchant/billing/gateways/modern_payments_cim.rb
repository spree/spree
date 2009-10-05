module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class ModernPaymentsCimGateway < Gateway #:nodoc:
      TEST_URL = "https://secure.modpay.com/netservices/test/ModpayTest.asmx"
      LIVE_URL = 'https://secure.modpay.com/ws/modpay.asmx'
      
      LIVE_XMLNS = "http://secure.modpay.com:81/ws/"
      TEST_XMLNS = "https://secure.modpay.com/netservices/test/"
      
      self.supported_countries = ['US']
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      self.homepage_url = 'http://www.modpay.com'
      self.display_name = 'Modern Payments'
      
      SUCCESS_MESSAGE = "Transaction accepted"
      FAILURE_MESSAGE = "Transaction failed"
      ERROR_MESSAGE   = "Transaction error"
      
      PAYMENT_METHOD = {
        :check => 1,
        :credit_card => 2
      }
      
      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options
        super
      end  
      
      def create_customer(options = {})
        post = {}
        add_customer_data(post, options)
        add_address(post, options)
        
        commit('CreateCustomer', post)
      end
      
      def modify_customer_credit_card(customer_id, credit_card)
        raise ArgumentError, "The customer_id cannot be blank" if customer_id.blank?
        
        post = {}
        add_customer_id(post, customer_id)
        add_credit_card(post, credit_card)
        
        commit('ModifyCustomerCreditCard', post)
      end
      
      def authorize_credit_card_payment(customer_id, amount)
        raise ArgumentError, "The customer_id cannot be blank" if customer_id.blank?
        
        post = {}
        add_customer_id(post, customer_id)
        add_amount(post, amount)
        
        commit('AuthorizeCreditCardPayment', post)
      end
      
      def create_payment(customer_id, amount, options = {})
        raise ArgumentError, "The customer_id cannot be blank" if customer_id.blank?
        
        post = {}
        add_customer_id(post, customer_id)
        add_amount(post, amount)
        add_payment_details(post, options)
        
        commit('CreatePayment', post)
      end

      private
      def add_payment_details(post, options)
        post[:pmtDate] = (options[:payment_date] || Time.now.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        post[:pmtType] = PAYMENT_METHOD[options[:payment_method] || :credit_card]
      end
      
      def add_amount(post, money)
        post[:pmtAmount] = amount(money)
      end
      
      def add_customer_id(post, customer_id)
        post[:custId] = customer_id
      end
      
      def add_customer_data(post, options)
        post[:acctNum]   = options[:customer]
      end
      
      def add_address(post, options)
        address = options[:billing_address] || options[:address] || {}
        
        if name = address[:name]
          segments = name.split(' ')
          post[:lastName] = segments.pop
          post[:firstName] = segments.join(' ')
        else
          post[:firstName] = address[:first_name]
          post[:lastName]  = address[:last_name]
        end
        
        post[:address]   = address[:address1]
        post[:city]      = address[:city]
        post[:state]     = address[:state]
        post[:zip]       = address[:zip]
        post[:phone]     = address[:phone]
        post[:fax]       = address[:fax]
        post[:email]     = address[:email]
      end
      
      def add_credit_card(post, credit_card)
        post[:ccName] = credit_card.name
        post[:ccNum]  = credit_card.number
        post[:expMonth] = credit_card.month
        post[:expYear]  = credit_card.year
      end
                
      def build_request(action, params)
        xml = Builder::XmlMarkup.new :indent => 2
        xml.instruct!
        xml.tag! 'env:Envelope',
          { 'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema',
            'xmlns:env' => 'http://schemas.xmlsoap.org/soap/envelope/',
            'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance' } do

          xml.tag! 'env:Body' do
            xml.tag! action, { "xmlns" => xmlns(action) } do
              xml.tag! "clientId", @options[:login]
              xml.tag! "clientCode", @options[:password]
              params.each {|key, value| xml.tag! key, value }
            end
          end
        end
        xml.target!
      end
      
      def xmlns(action)
        if test? && action == 'AuthorizeCreditCardPayment'
          TEST_XMLNS
        else
          LIVE_XMLNS
        end
      end
      
      def url(action)
        if test? && action == 'AuthorizeCreditCardPayment'
          TEST_URL
        else
          LIVE_URL
        end
      end
      
      def commit(action, params)
        data = ssl_post(url(action), build_request(action, params), 
                 { 'Content-Type' =>'text/xml; charset=utf-8', 
                   'SOAPAction' => "#{xmlns(action)}#{action}" }
                )

        response = parse(action, data)
        Response.new(successful?(action, response), message_from(action, response), response, 
          :test => test?, 
          :authorization => authorization_from(action, response),
          :avs_result => { :code => response[:avs_code] }
        )
      end
      
      def authorization_from(action, response)
        response[result_key(action)]
      end
      
      def result_key(action)
        action == "AuthorizeCreditCardPayment" ? :trans_id : "#{action.underscore}_result".to_sym
      end
      
      def successful?(action, response)
        response[result_key(action)].to_i > 0
      end
      
      def message_from(action, response)
        if response[:faultcode]
          ERROR_MESSAGE
        elsif successful?(action, response)
          SUCCESS_MESSAGE
        else
          FAILURE_MESSAGE
        end
      end
      
      def parse(action, xml)
        response = {}
        response[:action] = action
        
        xml = REXML::Document.new(xml)
        if root = REXML::XPath.first(xml, "//#{action}Response")
          root.elements.to_a.each do |node|
            parse_element(response, node)
          end
        elsif root = REXML::XPath.first(xml, "//soap:Fault")
          root.elements.to_a.each do |node|
            response[node.name.underscore.to_sym] = node.text
          end
        end

        response
      end
      
      def parse_element(response, node)
        if node.has_elements?
          node.elements.each{|e| parse_element(response, e) }
        else
          response[node.name.underscore.to_sym] = node.text
        end
      end
    end
  end
end

