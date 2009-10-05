#!ruby19
# encoding: utf-8

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SkipJackGateway < Gateway
      API_VERSION = '?.?'
      LIVE_URL = "https://www.skipjackic.com/scripts/evolvcc.dll"
      TEST_URL = "https://developer.skipjackic.com/scripts/evolvcc.dll"

      ACTIONS = {
        :authorization => 'AuthorizeAPI',
        :change_status => 'SJAPI_TransactionChangeStatusRequest',
        :get_status => 'SJAPI_TransactionStatusRequest'
      }
      
      SUCCESS_MESSAGE = 'The transaction was successful.'
      
      MONETARY_CHANGE_STATUSES = ['AUTHORIZE', 'AUTHORIZE ADDITIONAL', 'CREDIT', 'SPLITSETTLE']

      CARD_CODE_ERRORS = %w( N S "" )

      CARD_CODE_MESSAGES = {
        "M" => "Card verification number matched",
        "N" => "Card verification number didn't match",
        "P" => "Card verification number was not processed",
        "S" => "Card verification number should be on card but was not indicated",
        "U" => "Issuer was not certified for card verification",
        "" => "Transaction failed because incorrect card verification number was entered or no number was entered"
      }

      AVS_ERRORS = %w( A B C E I N O P R W Z )

      AVS_MESSAGES = {
        "A" => "Street address matches billing information, zip/postal code does not",
        "B" => "Street address match for international transaction. Postal code not verified due to incompatible formats",
        "C" => "Street address and postal code not verified for internation transaction due to incompatible formats",
        "D" => "Street address and postal code match for international transaction",
        "E" => "Address verification service error",
        "I" => "Address information not verified by international issuer",
        "M" => "Street address and postal code match for international transaction",
        "N" => "Neither street address nor zip/postal match billing information",
        "O" => "Non-US issuer does not participate",
        "P" => "Postal codes match for international transaction but street address not verified due to incompatible formats",
        "P" => "Address verification not applicable for this transaction",
        "R" => "Payment gateway was unavailable or timed out",
        "S" => "Address verification service not supported by issuer",
        "U" => "Address information is unavailable",
        "W" => "9-digit zip/postal code matches billing information, street address does not",
        "X" => "Street address and 9-digit zip/postal code matches billing information",
        "Y" => "Street address and 5-digit zip/postal code matches billing information",
        "Z" => "5-digit zip/postal code matches billing information, street address does not",
      }

      CHANGE_STATUS_ERROR_MESSAGES = {
        '0'  => 'Success',
        '-1' => 'Invalid Command',
        '-2' => 'Parameter Missing',
        '-3' => 'Failed retrieving response',
        '-4' => 'Invalid Status',
        '-5' => 'Failed reading security flags',
        '-6' => 'Developer serial number not found',
        '-7' => 'Invalid Serial Number'
      }

      TRANSACTION_CURRENT_STATUS = {
        '0' => 'Idle',
        '1' => 'Authorized',
        '2' => 'Denied',
        '3' => 'Settled',
        '4' => 'Credited',
        '5' => 'Deleted',
        '6' => 'Archived',
        '7' => 'Pre-Authorized',
        '8' => 'Split Settled'
      }

      TRANSACTION_PENDING_STATUS = {
        '0' => 'Idle',
        '1' => 'Pending Credit',
        '2' => 'Pending Settlement',
        '3' => 'Pending Authorization',
        '4' => 'Pending Manual Settlement',
        '5' => 'Pending Recurring'
      }
      
      RETURN_CODE_MESSAGES = {
        '-1' => 'Data was not by received intact by Skipjack Transaction Network.',
        '0' => 'Communication Failure. Error in Request and Response at IP level.',
        '1' => 'Valid Data. Authorization request was valid.',
        '-35' => 'Invalid credit card number. Retry with correct credit card number.',
        '-37' => 'Merchant Processor Unavailable. Skipjack is unable to communicate with payment Processor. Retry',
        '-39' => 'Length or value of HTML Serial. Number Invalid serial number. Check HTML Serial Number length and that it is a correct/valid number. Confirm you are sending to the correct environment (Development or Production)',
        '-51' => 'The value or length for billing zip code is incorrect.',
        '-52' => 'The value or length for shipping zip code is incorrect.',
        '-53' => 'The value or length for credit card expiration month is incorrect.',
        '-54' => 'The value or length of the month or year of the credit card account number was incorrect.',
        '-55' => 'The value or length or billing street address is incorrect.',
        '-56' => 'The value or length of the shipping address is incorrect.',
        '-57' => 'The length of the transaction amount must be at least 3 digits long (excluding the decimal place).',
        '-58' => 'Length or value in Merchant Name Merchant Name associated with Skipjack account is misconfigured or invalid',
        '-59' => 'Length or value in Merchant Address Merchant Address associated with Skipjack account is misconfigured or invalid',
        '-60' => 'Length or value in Merchant State Merchant State associated with Skipjack account is misconfigured or invalid',
        '-61' => 'The value or length for shipping state/province is empty.',
        '-62' => 'The value for length orderstring is empty.',
        '-64' => 'The value for the phone number is incorrect.',
        '-65' => 'The value or length for billing name is empty.',
        '-66' => 'The value or length for billing e-mail is empty.',
        '-67' => 'The value or length for billing street address is empty.',
        '-68' => 'The value or length for billing city is empty.',
        '-69' => 'The value or length for billing state is empty.',
        '-70' => 'Empty zipcode Zip Code field is empty.',
        '-71' => 'Empty ordernumber Ordernumber field is empty.',
        '-72' => 'Empty accountnumber Accountnumber field is empty',
        '-73' => 'Empty month Month field is empty.',
        '-74' => 'Empty year Year field is empty.',
        '-75' => 'Empty serialnumber Serialnumber field is empty.',
        '-76' => 'Empty transactionamount Transaction amount field is empty.',
        '-77' => 'Empty orderstring Orderstring field is empty.',
        '-78' => 'Empty shiptophone Shiptophone field is empty.',
        '-79' => 'The value or length for billing name is empty.',
        '-80' => 'Length shipto name Error in the length or value of shiptophone.',
        '-81' => 'Length or value of Customer location',
        '-82' => 'The value or length for billing state is empty.',
        '-83' => 'The value or length for shipping phone is empty.',
        '-84' => 'There is already an existing pending transaction in the register sharing the posted Order Number.',
        '-85' => 'Airline leg info invalid Airline leg field value is invalid or empty.',
        '-86' => 'Airline ticket info invalid Airline ticket info field is invalid or empty',
        '-87' => 'Point of Sale check routing number must be 9 numeric digits Point of Sale check routing number is invalid or empty.',
        '-88' => 'Point of Sale check account number missing or invalid Point of Sale check account number is invalid or empty.',
        '-89' => 'Point of Sale check MICR missing or invalid Point of Sale check MICR invalid or empty.',
        '-90' => 'Point of Sale check number missing or invalid Point of Sale check number invalid or empty.',
        '-91' => 'CVV2 Invalid or empty "Make CVV a required field feature" enabled (New feature 01 April 2006) in the Merchant Account Setup interface but no CVV code was sent in the transaction data.',
        '-92' => 'Approval Code Invalid Approval Code Invalid. Approval Code is a 6 digit code.',
        '-93' => 'Blind Credits Request Refused "Allow Blind Credits" option must be enabled on the Skipjack Merchant Account.',
        '-94' => 'Blind Credits Failed',
        '-95' => 'Voice Authorization Request Refused Voice Authorization option must be enabled on the Skipjack Merchant Account.',
        '-96' => 'Voice Authorizations Failed',
        '-97' => 'Fraud Rejection Violates Velocity Settling.',
        '-98' => 'Invalid Discount Amount',
        '-99' => 'POS PIN Debit Pin Block Debit-specific',
        '-100' => 'POS PIN Debit Invalid Key Serial Number Debit-specific',
        '-101' => 'Invalid Authentication Data Data for Verified by Visa/MC Secure Code is invalid.',
        '-102' => 'Authentication Data Not Allowed',
        '-103' => 'POS Check Invalid Birth Date POS check dateofbirth variable contains a birth date in an incorrect format. Use MM/DD/YYYY format for this variable.',
        '-104' => 'POS Check Invalid Identification Type POS check identificationtype variable contains a identification type value which is invalid. Use the single digit value where Social Security Number=1, Drivers License=2 for this variable.',
        '-105' => 'Invalid trackdata Track Data is in invalid format.',
        '-106' => 'POS Check Invalid Account Type',
        '-107' => 'POS PIN Debit Invalid Sequence Number',
        '-108' => 'Invalid Transaction ID',
        '-109' => 'Invalid From Account Type',
        '-110' => 'Pos Error Invalid To Account Type',
        '-112' => 'Pos Error Invalid Auth Option',
        '-113' => 'Pos Error Transaction Failed',
        '-114' => 'Pos Error Invalid Incoming Eci',
        '-115' => 'POS Check Invalid Check Type',
        '-116' => 'POS Check Invalid Lane Number POS Check lane or cash register number is invalid. Use a valid lane or cash register number that has been configured in the Skipjack Merchant Account.',
        '-117' => 'POS Check Invalid Cashier Number'
      }
      
      self.supported_countries = ['US', 'CA']
      self.supported_cardtypes = [:visa, :master, :american_express, :jcb, :discover, :diners_club]
      self.homepage_url = 'http://www.skipjack.com/'
      self.display_name = 'SkipJack'

      # Creates a new SkipJackGateway
      # 
      # The gateway requires that a valid login and password be passed
      # in the +options+ hash.
      # 
      # ==== Options
      #
      # * <tt>:login</tt> -- The SkipJack Merchant Serial Number.
      # * <tt>:password</tt> -- The SkipJack Developer Serial Number.
      # * <tt>:test => +true+ or +false+</tt> -- Use the test or live SkipJack url.
      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options
        super
      end
      
      def test?
        @options[:test] || super
      end
    
      def authorize(money, creditcard, options = {})
        requires!(options, :order_id, :email)
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_address(post, options)
        add_customer_data(post, options)
        commit(:authorization, money, post)
      end

      def purchase(money, creditcard, options = {})
        post = {}
        authorization = authorize(money, creditcard, options)
        if authorization.success?
          capture(money, authorization.authorization)
        else
          authorization
        end
      end

      # Captures the funds from an authorized transaction.
      # 
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be capture as an Integer in cents.
      # * <tt>authorization</tt> -- The authorization returned from the previous authorize request.
      # * <tt>options</tt> -- A hash of optional parameters.
      # 
      # ==== Options
      #
      # * <tt>:force_settlement</tt> -- Force the settlement to occur as soon as possible. This option is not supported by other gateways. See the SkipJack API reference for more details
      def capture(money, authorization, options = {})
        post = { }
        add_status_action(post, 'SETTLE')
        add_forced_settlement(post, options)
        add_transaction_id(post, authorization)
        commit(:change_status, money, post)
      end

      def void(authorization, options = {})
        post = {}
        add_status_action(post, 'DELETE')
        add_forced_settlement(post, options)
        add_transaction_id(post, authorization)
        commit(:change_status, nil, post)
      end

      def credit(money, identification, options = {})
        post = {}
        add_status_action(post, 'CREDIT')
        add_forced_settlement(post, options)
        add_transaction_id(post, identification)
        commit(:change_status, money, post)
      end

      def status(order_id)
        post = { }
        post[:szOrderNumber] = :order_id
        commit(:get_status, nil, post)
      end

      private
      def add_forced_settlement(post, options)
        post[:szForceSettlement] = options[:force_settlment] ? 1 : 0
      end
      
      def add_status_action(post, action)
        post[:szDesiredStatus] = action
      end
      
      def commit(action, money, parameters)
        response = parse( ssl_post( url_for(action), post_data(action, money, parameters) ), action )
        
        # Pass along the original transaction id in the case an update transaction
        Response.new(response[:success], message_from(response, action), response,
          :test => test?,
          :authorization => response[:szTransactionFileName] || parameters[:szTransactionId],
          :avs_result => { :code => response[:szAVSResponseCode] },
          :cvv_result => response[:szCVV2ResponseCode]
        )
      end
      
      def url_for(action)
        result = test? ? TEST_URL : LIVE_URL
        result += "?#{ACTIONS[action]}"
      end
      
      def add_credentials(params, action)
        if action == :authorization
          params[:SerialNumber] = @options[:login]
          params[:DeveloperSerialNumber] = @options[:password]
        else
          params[:szSerialNumber] = @options[:login]
          params[:szDeveloperSerialNumber] = @options[:password]
        end
      end
      
      def add_amount(params, action, money)
        if action == :authorization
          params[:TransactionAmount] = amount(money)
        else
          params[:szAmount] = amount(money) if MONETARY_CHANGE_STATUSES.include?(params[:szDesiredStatus])
        end
      end

      def parse(body, action)
        case action
        when :authorization
          parse_authorization_response(body)
        when :get_status
          parse_status_response(body, [ :SerialNumber, :TransactionAmount, :TransactionStatusCode, :TransactionStatusMessage, :OrderNumber, :TransactionDateTime, :TransactionID, :ApprovalCode, :BatchNumber ])
        else
          parse_status_response(body, [ :SerialNumber, :TransactionAmount, :DesiredStatus, :StatusResponse, :StatusResponseMessage, :OrderNumber, :AuditID ])
        end
      end
      
      def split_lines(body)
        body.split(/[\r\n]+/)
      end

      def split_line(line)
        line.split(/","/).collect { |key| key.sub(/"*([^"]*)"*/, '\1').strip; }
      end
      
      def authorize_response_map(body)
        lines = split_lines(body)
        keys, values = split_line(lines[0]), split_line(lines[1])
        Hash[*(keys.zip(values).flatten)].symbolize_keys
      end
      
      def parse_authorization_response(body)
        result = authorize_response_map(body)
        result[:success] = (result[:szIsApproved] == '1')
        result
      end

      def parse_status_response(body, response_keys)
        lines = split_lines(body)

        keys = [ :szSerialNumber, :szErrorCode, :szNumberRecords]
        values = split_line(lines[0])[0..2]

        result = Hash[*(keys.zip(values).flatten)]

        result[:szErrorMessage] = ''
        result[:success] = (result[:szErrorCode] == '0')

        if result[:success]
          lines[1..-1].each do |line|
            values = split_line(line)
            response_keys.each_with_index do |key, index|
              result[key] = values[index]
            end
          end
        else
          result[:szErrorMessage] = lines[1]
        end
        result
      end

      def post_data(action, money, params = {})
        add_credentials(params, action)
        add_amount(params, action, money)
        params.collect { |key, value| "#{key.to_s}=#{CGI.escape(value.to_s)}" }.join("&")
      end

      def add_transaction_id(post, transaction_id)
        post[:szTransactionId] = transaction_id
      end

      def add_invoice(post, options)
        post[:OrderNumber] = sanitize_order_id(options[:order_id])
        post[:CustomerCode] = options[:customer].to_s.slice(0, 17)
        post[:InvoiceNumber] = options[:invoice]
        post[:OrderDescription] = options[:description]
        
        if order_items = options[:items]
          post[:OrderString] = order_items.collect { |item| "#{item[:sku]}~#{item[:description].tr('~','-')}~#{item[:declared_value]}~#{item[:quantity]}~#{item[:taxable]}~~~~~~~~#{item[:tax_rate]}~||"}.join
        else
          post[:OrderString] = '1~None~0.00~0~N~||'
        end
      end

      def add_creditcard(post, creditcard)
        post[:AccountNumber]  = creditcard.number
        post[:Month] = creditcard.month
        post[:Year] = creditcard.year
        post[:CVV2] = creditcard.verification_value if creditcard.verification_value?
        post[:SJName] = creditcard.name
      end

      def add_customer_data(post, options)
        post[:Email] = options[:email]
      end

      def add_address(post, options)
        if address = options[:billing_address] || options[:address]
          post[:StreetAddress]  = address[:address1]
          post[:StreetAddress2] = address[:address2]
          post[:City]           = address[:city]
          post[:State]          = address[:state]
          post[:ZipCode]        = address[:zip]
          post[:Country]        = address[:country]
          post[:Phone]          = address[:phone]
          post[:Fax]            = address[:fax]
        end
        
        if address = options[:shipping_address]
          post[:ShipToName]           = address[:name]
          post[:ShipToStreetAddress]  = address[:address1]
          post[:ShipToStreetAddress2] = address[:address2]
          post[:ShipToCity]           = address[:city]
          post[:ShipToState]          = address[:state]
          post[:ShipToZipCode]        = address[:zip]
          post[:ShipToCountry]        = address[:country]
          post[:ShipToPhone]          = address[:phone]
          post[:ShipToFax]            = address[:fax]
        end
        
        # The phone number for the shipping address is required
        # Use the billing address phone number if a shipping address
        # phone number wasn't provided
        post[:ShipToPhone] = post[:Phone] if post[:ShipToPhone].blank?
      end

      def message_from(response, action)
        case action
        when :authorization
          message_from_authorization(response)
        when :get_status
          message_from_status(response)
        else
          message_from_status(response)
        end
      end

      def message_from_authorization(response)
        if response[:success]
          return SUCCESS_MESSAGE
        else
          return CARD_CODE_MESSAGES[response[:szCVV2ResponseCode]] if CARD_CODE_ERRORS.include?(response[:szCVV2ResponseCode])
          return AVS_MESSAGES[response[:szAVSResponseMessage]] if AVS_ERRORS.include?(response[:szAVSResponseCode])
          return RETURN_CODE_MESSAGES[response[:szReturnCode]] if response[:szReturnCode] != '1'
          return response[:szAuthorizationDeclinedMessage]
        end
      end

      def message_from_status(response)
        response[:success] ? SUCCESS_MESSAGE : response[:szErrorMessage]
      end
      
      def sanitize_order_id(value)
        value.to_s.gsub(/[^\w.]/, '')
      end
    end
  end
end
