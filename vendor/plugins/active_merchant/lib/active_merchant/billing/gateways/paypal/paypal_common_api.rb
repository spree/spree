module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # This module is included in both PaypalGateway and PaypalExpressGateway
    module PaypalCommonAPI
      def self.included(base)
        base.default_currency = 'USD'
        base.cattr_accessor :pem_file
        base.cattr_accessor :signature
      end
      
      API_VERSION = '52.0'
      
      URLS = {
        :test => { :certificate => 'https://api.sandbox.paypal.com/2.0/',
                   :signature   => 'https://api-3t.sandbox.paypal.com/2.0/' },
        :live => { :certificate => 'https://api-aa.paypal.com/2.0/',
                   :signature   => 'https://api-3t.paypal.com/2.0/' }
      }
      
      PAYPAL_NAMESPACE = 'urn:ebay:api:PayPalAPI'
      EBAY_NAMESPACE = 'urn:ebay:apis:eBLBaseComponents'
      
      ENVELOPE_NAMESPACES = { 'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema',
                              'xmlns:env' => 'http://schemas.xmlsoap.org/soap/envelope/',
                              'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance'
                            }
      CREDENTIALS_NAMESPACES = { 'xmlns' => PAYPAL_NAMESPACE,
                                 'xmlns:n1' => EBAY_NAMESPACE,
                                 'env:mustUnderstand' => '0'
                               }
      
      AUSTRALIAN_STATES = {
        'ACT' => 'Australian Capital Territory',
        'NSW' => 'New South Wales',
        'NT'  => 'Northern Territory',
        'QLD' => 'Queensland',
        'SA'  => 'South Australia',
        'TAS' => 'Tasmania',
        'VIC' => 'Victoria',
        'WA'  => 'Western Australia'
      }
      
      SUCCESS_CODES = [ 'Success', 'SuccessWithWarning' ]
      
      FRAUD_REVIEW_CODE = "11610"
      
      # The gateway must be configured with either your PayPal PEM file
      # or your PayPal API Signature.  Only one is required.
      #
      # <tt>:pem</tt>         The text of your PayPal PEM file. Note
      #                       this is not the path to file, but its
      #                       contents. If you are only using one PEM
      #                       file on your site you can declare it
      #                       globally and then you won't need to
      #                       include this option
      #
      # <tt>:signature</tt>   The text of your PayPal signature. 
      #                       If you are only using one API Signature
      #                       on your site you can declare it
      #                       globally and then you won't need to
      #                       include this option
      
      def initialize(options = {})
        requires!(options, :login, :password)
        
        @options = {
          :pem => pem_file,
          :signature => signature
        }.update(options)
        
        if @options[:pem].blank? && @options[:signature].blank?
          raise ArgumentError, "An API Certificate or API Signature is required to make requests to PayPal" 
        end
        
        super
      end
      
      def test?
        @options[:test] || Base.gateway_mode == :test
      end

      def reauthorize(money, authorization, options = {})
        commit 'DoReauthorization', build_reauthorize_request(money, authorization, options)
      end
      
      def capture(money, authorization, options = {})
        commit 'DoCapture', build_capture_request(money, authorization, options)
      end
      
      # Transfer money to one or more recipients.
      #
      #   gateway.transfer 1000, 'bob@example.com',
      #     :subject => "The money I owe you", :note => "Sorry it's so late"
      #
      #   gateway.transfer [1000, 'fred@example.com'],
      #     [2450, 'wilma@example.com', :note => 'You will receive another payment on 3/24'],
      #     [2000, 'barney@example.com'],
      #     :subject => "Your Earnings", :note => "Thanks for your business."
      #
      def transfer(*args)
        commit 'MassPay', build_mass_pay_request(*args)
      end

      def void(authorization, options = {})
        commit 'DoVoid', build_void_request(authorization, options)
      end
      
      def credit(money, identification, options = {})
        commit 'RefundTransaction', build_credit_request(money, identification, options)
      end

      private
      def build_reauthorize_request(money, authorization, options)
        xml = Builder::XmlMarkup.new
        
        xml.tag! 'DoReauthorizationReq', 'xmlns' => PAYPAL_NAMESPACE do
          xml.tag! 'DoReauthorizationRequest', 'xmlns:n2' => EBAY_NAMESPACE do
            xml.tag! 'n2:Version', API_VERSION
            xml.tag! 'AuthorizationID', authorization
            xml.tag! 'Amount', amount(money), 'currencyID' => options[:currency] || currency(money)
          end
        end

        xml.target!        
      end
          
      def build_capture_request(money, authorization, options)   
        xml = Builder::XmlMarkup.new
        
        xml.tag! 'DoCaptureReq', 'xmlns' => PAYPAL_NAMESPACE do
          xml.tag! 'DoCaptureRequest', 'xmlns:n2' => EBAY_NAMESPACE do
            xml.tag! 'n2:Version', API_VERSION
            xml.tag! 'AuthorizationID', authorization
            xml.tag! 'Amount', amount(money), 'currencyID' => options[:currency] || currency(money)
            xml.tag! 'CompleteType', 'Complete'
            xml.tag! 'Note', options[:description]
          end
        end

        xml.target!        
      end
      
      def build_credit_request(money, identification, options)
        xml = Builder::XmlMarkup.new
            
        xml.tag! 'RefundTransactionReq', 'xmlns' => PAYPAL_NAMESPACE do
          xml.tag! 'RefundTransactionRequest', 'xmlns:n2' => EBAY_NAMESPACE do
            xml.tag! 'n2:Version', API_VERSION
            xml.tag! 'TransactionID', identification
            xml.tag! 'Amount', amount(money), 'currencyID' => options[:currency] || currency(money)
            xml.tag! 'RefundType', 'Partial'
            xml.tag! 'Memo', options[:note] unless options[:note].blank?
          end
        end
      
        xml.target!        
      end
      
      def build_void_request(authorization, options)
        xml = Builder::XmlMarkup.new
        
        xml.tag! 'DoVoidReq', 'xmlns' => PAYPAL_NAMESPACE do
          xml.tag! 'DoVoidRequest', 'xmlns:n2' => EBAY_NAMESPACE do
            xml.tag! 'n2:Version', API_VERSION
            xml.tag! 'AuthorizationID', authorization
            xml.tag! 'Note', options[:description]
          end
        end

        xml.target!        
      end
      
      def build_mass_pay_request(*args)   
        default_options = args.last.is_a?(Hash) ? args.pop : {}
        recipients = args.first.is_a?(Array) ? args : [args]
        
        xml = Builder::XmlMarkup.new
        
        xml.tag! 'MassPayReq', 'xmlns' => PAYPAL_NAMESPACE do
          xml.tag! 'MassPayRequest', 'xmlns:n2' => EBAY_NAMESPACE do
            xml.tag! 'n2:Version', API_VERSION
            xml.tag! 'EmailSubject', default_options[:subject] if default_options[:subject]
            recipients.each do |money, recipient, options|
              options ||= default_options
              xml.tag! 'MassPayItem' do
                xml.tag! 'ReceiverEmail', recipient
                xml.tag! 'Amount', amount(money), 'currencyID' => options[:currency] || currency(money)
                xml.tag! 'Note', options[:note] if options[:note]
                xml.tag! 'UniqueId', options[:unique_id] if options[:unique_id]
              end
            end
          end
        end
        
        xml.target!
      end

      def parse(action, xml)
        response = {}
        
        error_messages = []
        error_codes = []
        
        xml = REXML::Document.new(xml)
        if root = REXML::XPath.first(xml, "//#{action}Response")
          root.elements.each do |node|            
            case node.name
            when 'Errors'
              short_message = nil
              long_message = nil
              
              node.elements.each do |child|
                case child.name
                when "LongMessage"
                  long_message = child.text unless child.text.blank?
                when "ShortMessage"
                  short_message = child.text unless child.text.blank?
                when "ErrorCode"
                  error_codes << child.text unless child.text.blank?
                end
              end

              if message = long_message || short_message
                error_messages << message
              end
            else
              parse_element(response, node)
            end
          end
          response[:message] = error_messages.uniq.join(". ") unless error_messages.empty?
          response[:error_codes] = error_codes.uniq.join(",") unless error_codes.empty?
        elsif root = REXML::XPath.first(xml, "//SOAP-ENV:Fault")
          parse_element(response, root)
          response[:message] = "#{response[:faultcode]}: #{response[:faultstring]} - #{response[:detail]}"
        end

        response
      end

      def parse_element(response, node)
        if node.has_elements?
          node.elements.each{|e| parse_element(response, e) }
        else
          response[node.name.underscore.to_sym] = node.text
          node.attributes.each do |k, v|
            response["#{node.name.underscore}_#{k.underscore}".to_sym] = v if k == 'currencyID'
          end
        end
      end

      def build_request(body)
        xml = Builder::XmlMarkup.new
        
        xml.instruct!
        xml.tag! 'env:Envelope', ENVELOPE_NAMESPACES do
          xml.tag! 'env:Header' do
            add_credentials(xml)
          end
          
          xml.tag! 'env:Body' do
            xml << body
          end
        end
        xml.target!
      end
     
      def add_credentials(xml)
        xml.tag! 'RequesterCredentials', CREDENTIALS_NAMESPACES do
          xml.tag! 'n1:Credentials' do
            xml.tag! 'Username', @options[:login]
            xml.tag! 'Password', @options[:password]
            xml.tag! 'Subject', @options[:subject]
            xml.tag! 'Signature', @options[:signature] unless @options[:signature].blank?
          end
        end
      end
      
      def add_address(xml, element, address)
        return if address.nil?
        xml.tag! element do
          xml.tag! 'n2:Name', address[:name]
          xml.tag! 'n2:Street1', address[:address1]
          xml.tag! 'n2:Street2', address[:address2]
          xml.tag! 'n2:CityName', address[:city]
          xml.tag! 'n2:StateOrProvince', address[:state].blank? ? 'N/A' : address[:state]
          xml.tag! 'n2:Country', address[:country]
          xml.tag! 'n2:PostalCode', address[:zip]
          xml.tag! 'n2:Phone', address[:phone]
        end
      end
      
      def endpoint_url
        URLS[test? ? :test : :live][@options[:signature].blank? ? :certificate : :signature]
      end

      def commit(action, request)
        response = parse(action, ssl_post(endpoint_url, build_request(request)))
       
        build_response(successful?(response), message_from(response), response,
    	    :test => test?,
    	    :authorization => authorization_from(response),
    	    :fraud_review => fraud_review?(response),
    	    :avs_result => { :code => response[:avs_code] },
    	    :cvv_result => response[:cvv2_code]
        )
      end
      
      def fraud_review?(response)
        response[:error_codes] == FRAUD_REVIEW_CODE
      end
      
      def authorization_from(response)
        response[:transaction_id] || response[:authorization_id] || response[:refund_transaction_id] # middle one is from reauthorization
      end
      
      def successful?(response)
        SUCCESS_CODES.include?(response[:ack])
      end
      
      def message_from(response)
        response[:message] || response[:ack]
      end
    end
  end
end