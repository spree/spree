module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # PayJunction Gateway
    #
    # This gateway accepts the following arguments:
    #   :login    => your PayJunction username
    #   :password => your PayJunction pass
    # 
    # Example use:
    #
    #   gateway = ActiveMerchant::Billing::Base.gateway(:pay_junction).new(
    #               :login => "my_account", 
    #               :password => "my_pass"
    #            )
    #
    #   # set up credit card obj as in main ActiveMerchant example
    #   creditcard = ActiveMerchant::Billing::CreditCard.new(
    #     :type       => 'visa',
    #     :number     => '4242424242424242',
    #     :month      => 8,
    #     :year       => 2009,
    #     :first_name => 'Bob',
    #     :last_name  => 'Bobsen'
    #   )
    #
    #   # optionally specify address if using AVS
    #   address = { :address1 => '101 Test Ave', :city => 'Test', :state => 'TS',
    #               :zip  => '10101', :country => 'US' }
    #
    #   # run request
    #   response = gateway.purchase(1000, creditcard, :address => address) # charge 10 dollars
    #
    # 1) Check whether the transaction was successful
    #
    #   response.success?
    #
    # 2) Retrieve the message returned by PayJunction
    #
    #   response.message
    #
    # 3) Retrieve the unique transaction ID returned by PayJunction
    #
    #   response.authorization
    #
    # This gateway supports "instant" transactions. These transactions allow you
    # to execute an operation on a previously run card without card information
    # provided you have the transaction id from a previous transaction with the
    # same card. All functions that take a credit card object for this gateway
    # can take a transaction id string instead.
    #
    # Test Transactions
    #
    # See the source for initialize() for test account information. Note that
    # PayJunction does not allow test transactions on your account, so if the 
    # gateway is running in :test mode your transaction will be run against
    # PayJunction's global test account and will not show up in your account.
    #
    # Transactions ran on this account go through a test processor, so there is no 
    # need to void or otherwise cancel transactions. However, for further safety, 
    # please use the special card numbers 4433221111223344 or 4444333322221111 and 
    # keep transaction amounts below $4.00 when testing.  
    #
    # Also note, transactions ran for an amount between $0.00 and $1.99 will likely
    # result in denial. To demonstrate approvals, use amounts between $2.00 and $4.00.
    #
    # Test transactions can be checked by logging into
    # PayJunction Web Login with username 'pj-cm-01' and password 'pj-cm-01p'
    #
    # Usage Details
    # 
    # Below is a map of values accepted by PayJunction and how you should submit
    # each to ActiveMerchant
    #
    # PayJunction Field       ActiveMerchant Use
    # 
    # dc_logon                provide as :login value to gateway instantation
    # dc_password             provide as :password value to gateway instantiation
    #
    # dc_name                 will be retrieved from credit_card.name
    # dc_first_name           :first_name on CreditCard object instantation
    # dc_last_name            :last_name  on CreditCard object instantation
    # dc_number               :number     on CreditCard object instantation
    # dc_expiration_month     :month      on CreditCard object instantation
    # dc_expiration_year      :year       on CreditCard object instantation
    # dc_verification_number  :verification_value on CC object instantation
    #
    # dc_transaction_amount   include as argument to method for your transaction type
    # dc_transaction_type     do nothing, set by your transaction type
    # dc_version              do nothing, always "1.2"
    #
    # dc_transaction_id       submit as a string in place of CreditCard obj for
    #                         "instant" transactions.
    #
    # dc_invoice              :order_id in options for transaction method
    # dc_notes                :description in options for transaction method
    #
    # See example use above for address AVS fields
    # See #recurring for periodic transaction fields
    class PayJunctionGateway < Gateway
      API_VERSION   = '1.2'

      class_inheritable_accessor :test_url, :live_url

      self.test_url = "https://demo.payjunction.com/quick_link"
      self.live_url = "https://payjunction.com/quick_link"

      TEST_LOGIN = 'pj-ql-01'
      TEST_PASSWORD = 'pj-ql-01p'
      
      SUCCESS_CODES = ["00", "85"]
      SUCCESS_MESSAGE = 'The transaction was approved.'
      
      FAILURE_MESSAGE = 'The transaction was declined.'
      
      DECLINE_CODES = {
        "AE"  => 'Address verification failed because address did not match.',
        'ZE'  => 'Address verification failed because zip did not match.',
        'XE'  => 'Address verification failed because zip and address did not match.',
        'YE'  => 'Address verification failed because zip and address did not match.',
        'OE'  => 'Address verification failed because address or zip did not match.',
        'UE'  => 'Address verification failed because cardholder address unavailable.',
        'RE'  => 'Address verification failed because address verification system is not working.',
        'SE'  => 'Address verification failed because address verification system is unavailable.',
        'EE'  => 'Address verification failed because transaction is not a mail or phone order.',
        'GE'  => 'Address verification failed because international support is unavailable.',
        'CE'  => 'Declined because CVV2/CVC2 code did not match.',
        '04'  => 'Declined. Pick up card.',
        '07'  => 'Declined. Pick up card (Special Condition).',
        '41'  => 'Declined. Pick up card (Lost).',
        '43'  => 'Declined. Pick up card (Stolen).',
        '13'  => 'Declined because of the amount is invalid.',
        '14'  => 'Declined because the card number is invalid.',
        '80'  => 'Declined because of an invalid date.',
        '05'  => 'Declined. Do not honor.',
        '51'  => 'Declined because of insufficient funds.',
        'N4'  => 'Declined because the amount exceeds issuer withdrawal limit.',
        '61'  => 'Declined because the amount exceeds withdrawal limit.',
        '62'  => 'Declined because of an invalid service code (restricted).',
        '65'  => 'Declined because the card activity limit exceeded.',
        '93'  => 'Declined because there a violation (the transaction could not be completed).',
        '06'  => 'Declined because address verification failed.',
        '54'  => 'Declined because the card has expired.',
        '15'  => 'Declined because there is no such issuer.',
        '96'  => 'Declined because of a system error.',
        'N7'  => 'Declined because of a CVV2/CVC2 mismatch.',
        'M4'  => 'Declined.', 
        "FE"  => "There was a format error with your Trinity Gateway Service (API) request.",
        "LE"  => "Could not log you in (problem with dc_logon and/or dc_password).",
        'NL'  => 'Aborted because of a system error, please try again later. ',
        'AB'  => 'Aborted because of an upstream system error, please try again later.'
      }
      
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      self.supported_countries = ['US']
      self.homepage_url = 'http://www.payjunction.com/'
      self.display_name = 'PayJunction'

      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options
        super
      end
      
      # The first half of the preauth(authorize)/postauth(capture) model.
      # Checks to make sure funds are available for a transaction, and returns a
      # transaction_id that can be used later to postauthorize (capture) the funds.
      def authorize(money, payment_source, options = {})
        parameters = {
          :transaction_amount => amount(money),
        }                                                             
        
        add_payment_source(parameters, payment_source)
        add_address(parameters, options)
        add_optional_fields(parameters, options)
        commit('AUTHORIZATION', parameters)
      end
      
      # A simple sale, capturing funds immediately.
      # Execute authorization and capture in a single step.
      def purchase(money, payment_source, options = {})        
        parameters = {
          :transaction_amount => amount(money),
        }                                                             
        
        add_payment_source(parameters, payment_source)
        add_address(parameters, options)
        add_optional_fields(parameters, options)
        commit('AUTHORIZATION_CAPTURE', parameters)
      end

      # The second half of the preauth(authorize)/postauth(capture) model.
      # Retrieve funds that have been previously authorized with _authorization_
      def capture(money, authorization, options = {})
        parameters = {
          :transaction_id => authorization,
          :posture => 'capture'
        }
        
        add_optional_fields(parameters, options)                                          
        commit('update', parameters)
      end
      
      # Return money to a card that was previously billed.
      # _authorization_ should be the transaction id of the transaction we are returning.
      def credit(money, authorization, options = {})  
        parameters = {
          :transaction_amount => amount(money),
          :transaction_id => authorization
        }
                                                  
        commit('CREDIT', parameters)
      end
      
      # Cancel a transaction that has been charged but has not yet made it
      # through the batch process.
      def void(money, authorization, options = {})
        parameters = {
          :transaction_id => authorization,
          :posture => 'void'
        }
        
        add_optional_fields(parameters, options)                                          
        commit('update', parameters)
      end
      
      # Set up a sale that will be made on a regular basis for the same amount 
      # (ex. $20 a month for 12 months)
      #
      # The parameter :periodicity should be specified as either :monthly, :weekly, or :daily
      # The parameter :payments should be the number of payments to be made
      #
      #   gateway.recurring('2000', creditcard, :periodicity => :monthly, :payments => 12)
      #
      # The optional parameter :starting_at takes a date or time argument or a string in 
      # YYYYMMDD format and can be used to specify when the first charge will be made. 
      # If omitted the first charge will be immediate.      
      def recurring(money, payment_source, options = {})        
        requires!(options, [:periodicity, :monthly, :weekly, :daily], :payments)
      
        periodic_type = case options[:periodicity]
        when :monthly
          'month'
        when :weekly
          'week'
        when :daily
          'day'
        end
        
        if options[:starting_at].nil?
          start_date = Time.now.strftime('%Y-%m-%d')
        elsif options[:starting_at].is_a?(String)
          sa = options[:starting_at]
          start_date = "#{sa[0..3]}-#{sa[4..5]}-#{sa[6..7]}"
        else
          start_date = options[:starting_at].strftime('%Y-%m-%d')
        end
        
        parameters = {
          :transaction_amount => amount(money),
          :schedule_periodic_type => periodic_type,
          :schedule_create => 'true',
          :schedule_limit => options[:payments].to_i > 1 ? options[:payments] : 1,
          :schedule_periodic_number => 1,
          :schedule_start => start_date
        }
        
        add_payment_source(parameters, payment_source)
        add_optional_fields(parameters, options)
        add_address(parameters, options)                                   
        commit('AUTHORIZATION_CAPTURE', parameters)
      end
      
      def test?
        test_login? || @options[:test] || super
      end

      private
      
      def test_login?
        @options[:login] == TEST_LOGIN && @options[:password] == TEST_PASSWORD
      end
      
      # add fields depending on payment source selected (cc or transaction id)
      def add_payment_source(params, source)
        if source.is_a?(String)
          add_billing_id(params, source)
        else
          add_creditcard(params, source)
        end
      end
      
      # add fields for credit card
      def add_creditcard(params, creditcard)
        params[:name]                 = creditcard.name
        params[:number]               = creditcard.number
        params[:expiration_month]     = creditcard.month
        params[:expiration_year]      = creditcard.year 
        params[:verification_number]  = creditcard.verification_value if creditcard.verification_value?
      end
      
      # add field for "instant" transaction, using previous transaction id
      def add_billing_id(params, billingid)
        params[:transaction_id] = billingid
      end
      
      # add address fields if present
      def add_address(params, options)
        address = options[:billing_address] || options[:address]
        
        if address          
          params[:address]  = address[:address1] unless address[:address1].blank?
          params[:city]      = address[:city]     unless address[:city].blank?
          params[:state]     = address[:state]    unless address[:state].blank?
          params[:zipcode]   = address[:zip]      unless address[:zip].blank?
          params[:country]   = address[:country]  unless address[:country].blank?
        end     
      end
      
      def add_optional_fields(params, options)
        params[:notes] = options[:description] unless options[:description].blank?
        params[:invoice] = options[:order_id].to_s.gsub(/[^-\/\w.,']/, '') unless options[:order_id].blank?
      end
      
      def commit(action, parameters)
        url = test? ? self.test_url : self.live_url

        response = parse( ssl_post(url, post_data(action, parameters)) )
        
        Response.new(successful?(response), message_from(response), response, 
          :test => test?, 
          :authorization => response[:transaction_id] || parameters[:transaction_id]
        )
      end
      
      def successful?(response)
        SUCCESS_CODES.include?(response[:response_code]) || response[:query_status] == true
      end
      
      def message_from(response)
        if successful?(response)
          SUCCESS_MESSAGE
        else
          DECLINE_CODES[response[:response_code]] || FAILURE_MESSAGE
        end
      end
      
      def post_data(action, params)
        if test?
          # test requests must use global test account
          params[:logon]      = TEST_LOGIN
          params[:password]   = TEST_PASSWORD
        else
          params[:logon]      = @options[:login]
          params[:password]   = @options[:password]
        end
        params[:version] = API_VERSION
        params[:transaction_type] = action
        
        params.reject{|k,v| v.blank?}.collect{ |k, v| "dc_#{k.to_s}=#{CGI.escape(v.to_s)}" }.join("&")
      end
      
      def parse(body)
        # PayJunction uses the Field Separator ASCII character to separate key/val
        # pairs in the response. The <FS> character's octal value is 034.
        #
        # Sample response:
        # 
        # transaction_id=44752<FS>response_code=M4<FS>response_message=Declined (INV TEST CARD).  
        
        pairs = body.chomp.split("\034")
        response = {}
        pairs.each do |pair|
          key, val = pair.split('=')
          response[key[3..-1].to_sym] = val ? normalize(val) : nil
        end
        response
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
      
    end
  end
end