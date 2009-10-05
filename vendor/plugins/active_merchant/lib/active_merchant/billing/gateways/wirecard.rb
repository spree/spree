require 'base64'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class WirecardGateway < Gateway
      # Test server location
      TEST_URL = 'https://c3-test.wirecard.com/secure/ssl-gateway'
     
      # Live server location
      LIVE_URL = 'https://c3.wirecard.com/secure/ssl-gateway'

      # The Namespaces are not really needed, because it just tells the System, that there's actually no namespace used.
      # It's just specified here for completeness.
      ENVELOPE_NAMESPACES = {
        'xmlns:xsi' => 'http://www.w3.org/1999/XMLSchema-instance',
				'xsi:noNamespaceSchemaLocation' => 'wirecard.xsd'
			}

			PERMITTED_TRANSACTIONS = %w[ AUTHORIZATION CAPTURE_AUTHORIZATION PURCHASE ]

      RETURN_CODES = %w[ ACK NOK ]

      # Wirecard only allows phone numbers with a format like this: +xxx(yyy)zzz-zzzz-ppp, where: 
      #   xxx = Country code 
      #   yyy = Area or city code 
      #   zzz-zzzz = Local number 
      #   ppp = PBX extension 
      # For example, a typical U.S. or Canadian number would be "+1(202)555-1234-739" indicating PBX extension 739 at phone 
      # number 5551234 within area code 202 (country code 1).
      VALID_PHONE_FORMAT = /\+\d{1,3}(\(?\d{3}\)?)?\d{3}-\d{4}-\d{3}/
      
      # The countries the gateway supports merchants from as 2 digit ISO country codes
      # TODO: Check supported countries
      self.supported_countries = ['DE']

      # Wirecard supports all major credit and debit cards:
      # Visa, Mastercard, American Express, Diners Club,
      # JCB, Switch, VISA Carte Bancaire, Visa Electron and UATP cards.
      # They also support the latest anti-fraud systems such as Verified by Visa or Master Secure Code.
      self.supported_cardtypes = [
        :visa, :master, :american_express, :diners_club, :jcb, :switch
      ]

      # The homepage URL of the gateway
      self.homepage_url = 'http://www.wirecard.com'

      # The name of the gateway
      self.display_name = 'Wirecard'

      # The currency should normally be EUROs
      self.default_currency = 'EUR'

      # 100 is 1.00 Euro
      self.money_format = :cents

      def initialize(options = {})
        # verify that username and password are supplied
        requires!(options, :login, :password)
        # unfortunately Wirecard also requires a BusinessCaseSignature in the XML request
        requires!(options, :signature)
        @options = options
        super
      end

      # Should run against the test servers or not?
      def test?
        @options[:test] || super
      end

      # Authorization
      def authorize(money, creditcard, options = {})
        prepare_options_hash(options)
        @options[:credit_card] = creditcard
        request = build_request(:authorization, money, @options)
        commit(request)
      end


      # Capture Authorization
      def capture(money, authorization, options = {})
        prepare_options_hash(options)
        @options[:authorization] = authorization
        request = build_request(:capture_authorization, money, @options)
        commit(request)
      end


      # Purchase
      def purchase(money, creditcard, options = {})
        prepare_options_hash(options)
        @options[:credit_card] = creditcard
        request = build_request(:purchase, money, @options)
        commit(request)
      end

    private

      def prepare_options_hash(options)
        @options.update(options)
        setup_address_hash!(options)
      end

      # Create all address hash key value pairs so that
      # it still works if only provided with one or two of them
      def setup_address_hash!(options)
        options[:billing_address] = options[:billing_address] || options[:address] || {}
        options[:shipping_address] = options[:shipping_address] || {}
        # Include Email in address-hash from options-hash
        options[:billing_address][:email] = options[:email] if options[:email]
      end

      # Contact WireCard, make the XML request, and parse the
      # reply into a Response object
      def commit(request)
	      headers = { 'Content-Type' => 'text/xml',
	                  'Authorization' => encoded_credentials }

	      response = parse(ssl_post(test? ? TEST_URL : LIVE_URL, request, headers))
        # Pending Status also means Acknowledged (as stated in their specification)
	      success = response[:FunctionResult] == "ACK" || response[:FunctionResult] == "PENDING"
	      message = response[:Message]
        authorization = (success && @options[:action] == :authorization) ? response[:GuWID] : nil

        Response.new(success, message, response,
          :test => test?,
          :authorization => authorization,
          :avs_result => { :code => response[:avsCode] },
          :cvv_result => response[:cvCode]
        )
      end

      # Generates the complete xml-message, that gets sent to the gateway
      def build_request(action, money, options = {})
				xml = Builder::XmlMarkup.new :indent => 2
				xml.instruct!
				xml.tag! 'WIRECARD_BXML' do
				  xml.tag! 'W_REQUEST' do
          xml.tag! 'W_JOB' do
              # TODO: OPTIONAL, check what value needs to be insert here
              xml.tag! 'JobID', 'test dummy data'
              # UserID for this transaction
              xml.tag! 'BusinessCaseSignature', options[:signature] || options[:login]
              # Create the whole rest of the message
              add_transaction_data(xml, action, money, options)
				    end
				  end
				end
				xml.target!
      end

      # Includes the whole transaction data (payment, creditcard, address)
      def add_transaction_data(xml, action, money, options = {})
        options[:action] = action
        # TODO: require order_id instead of auto-generating it if not supplied
        options[:order_id] ||= generate_unique_id
        transaction_type = action.to_s.upcase

        xml.tag! "FNC_CC_#{transaction_type}" do
          # TODO: OPTIONAL, check which param should be used here
          xml.tag! 'FunctionID', options[:description] || 'Test dummy FunctionID'

          xml.tag! 'CC_TRANSACTION' do
            xml.tag! 'TransactionID', options[:order_id]
            if [:authorization, :purchase].include?(action)
              add_invoice(xml, money, options)
              add_creditcard(xml, options[:credit_card])
              add_address(xml, options[:billing_address])
            elsif action == :capture_authorization
              xml.tag! 'GuWID', options[:authorization] if options[:authorization]
            end
          end
        end
      end

			# Includes the payment (amount, currency, country) to the transaction-xml
      def add_invoice(xml, money, options)
        xml.tag! 'Amount', amount(money)
        xml.tag! 'Currency', options[:currency] || currency(money)
        xml.tag! 'CountryCode', options[:billing_address][:country]
        xml.tag! 'RECURRING_TRANSACTION' do
          xml.tag! 'Type', options[:recurring] || 'Single'
        end
      end

			# Includes the credit-card data to the transaction-xml
			def add_creditcard(xml, creditcard)
        raise "Creditcard must be supplied!" if creditcard.nil?
        xml.tag! 'CREDIT_CARD_DATA' do
          xml.tag! 'CreditCardNumber', creditcard.number
          xml.tag! 'CVC2', creditcard.verification_value
          xml.tag! 'ExpirationYear', creditcard.year
          xml.tag! 'ExpirationMonth', format(creditcard.month, :two_digits)
          xml.tag! 'CardHolderName', [creditcard.first_name, creditcard.last_name].join(' ')
        end
      end

			# Includes the IP address of the customer to the transaction-xml
      def add_customer_data(xml, options)
        return unless options[:ip]
				xml.tag! 'CONTACT_DATA' do
					xml.tag! 'IPAddress', options[:ip]
				end
			end

      # Includes the address to the transaction-xml
      def add_address(xml, address)
        return if address.nil?
        xml.tag! 'CORPTRUSTCENTER_DATA' do
	        xml.tag! 'ADDRESS' do
	          xml.tag! 'Address1', address[:address1]
	          xml.tag! 'Address2', address[:address2] if address[:address2]
	          xml.tag! 'City', address[:city]
	          xml.tag! 'ZipCode', address[:zip]
	          
	          if address[:state] =~ /[A-Za-z]{2}/ && address[:country] =~ /^(us|ca)$/i
	            xml.tag! 'State', address[:state].upcase
	          end
	          
	          xml.tag! 'Country', address[:country]
            xml.tag! 'Phone', address[:phone] if address[:phone] =~ VALID_PHONE_FORMAT
	          xml.tag! 'Email', address[:email]
	        end
	      end
      end


      # Read the XML message from the gateway and check if it was successful,
			# and also extract required return values from the response.
      def parse(xml)
        basepath = '/WIRECARD_BXML/W_RESPONSE'
        response = {}

        xml = REXML::Document.new(xml)
        if root = REXML::XPath.first(xml, "#{basepath}/W_JOB")
          parse_response(response, root)
        elsif root = REXML::XPath.first(xml, "//ERROR")
          parse_error(response, root)
        else
          response[:Message] = "No valid XML response message received. \
                                Propably wrong credentials supplied with HTTP header."
        end

        response
      end

      # Parse the <ProcessingStatus> Element which containts all important information
      def parse_response(response, root)
        status = nil
        # get the root element for this Transaction
        root.elements.to_a.each do |node|
          if node.name =~ /FNC_CC_/
            status = REXML::XPath.first(node, "CC_TRANSACTION/PROCESSING_STATUS")
          end
        end
        message = ""
        if status
          if info = status.elements['Info']
            message << info.text
          end
          # Get basic response information
          status.elements.to_a.each do |node|
            response[node.name.to_sym] = (node.text || '').strip
          end
        end
        parse_error(root, message)
        response[:Message] = message
      end

      # Parse a generic error response from the gateway
      def parse_error(root, message = "")
        # Get errors if available and append them to the message
        errors = errors_to_string(root)
        unless errors.strip.blank?
          message << ' - ' unless message.strip.blank?
          message << errors
        end
        message
      end

      # Parses all <ERROR> elements in the response and converts the information
      # to a single string
      def errors_to_string(root)
        # Get context error messages (can be 0..*)
        errors = []
        REXML::XPath.each(root, "//ERROR") do |error_elem|
          error = {}
          error[:Advice] = []
          error[:Message] = error_elem.elements['Message'].text
          error_elem.elements.each('Advice') do |advice|
            error[:Advice] << advice.text
          end
          errors << error
        end
        # Convert all messages to a single string
        string = ''
        errors.each do |error|
          string << error[:Message]
          error[:Advice].each_with_index do |advice, index|
            string << ' (' if index == 0
            string << "#{index+1}. #{advice}"
            string << ' and ' if index < error[:Advice].size - 1
            string << ')' if index == error[:Advice].size - 1
          end
        end
        string
      end

      # Encode login and password in Base64 to supply as HTTP header
      # (for http basic authentication)
      def encoded_credentials
        credentials = [@options[:login], @options[:password]].join(':')
        "Basic " << Base64.encode64(credentials).strip
      end
      
    end
  end
end

