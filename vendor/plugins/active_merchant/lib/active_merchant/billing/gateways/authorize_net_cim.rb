module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # ==== Customer Information Manager (CIM)
    # 
    # The Authorize.Net Customer Information Manager (CIM) is an optional additional service that allows you to store sensitive payment information on
    # Authorize.Net's servers, simplifying payments for returning customers and recurring transactions. It can also help with Payment Card Industry (PCI) 
    # Data Security Standard compliance, since customer data is no longer stored locally.
    # 
    # To use the AuthorizeNetCimGateway CIM must be enabled for your account.
    # 
    # Information about CIM is available on the {Authorize.Net website}[http://www.authorize.net/solutions/merchantsolutions/merchantservices/cim/].
    # Information about the CIM API is available at the {Authorize.Net Integration Center}[http://developer.authorize.net/]
    # 
    # ==== Login and Password
    # 
    # The login and password are not the username and password you use to 
    # login to the Authorize.Net Merchant Interface. Instead, you will 
    # use the API Login ID as the login and Transaction Key as the 
    # password.
    # 
    # ==== How to Get Your API Login ID and Transaction Key
    #
    # 1. Log into the Merchant Interface
    # 2. Select Settings from the Main Menu
    # 3. Click on API Login ID and Transaction Key in the Security section
    # 4. Type in the answer to the secret question configured on setup
    # 5. Click Submit
    class AuthorizeNetCimGateway < Gateway
    
      class_inheritable_accessor :test_url, :live_url

      self.test_url = 'https://apitest.authorize.net/xml/v1/request.api'
      self.live_url = 'https://api.authorize.net/xml/v1/request.api'
      
      AUTHORIZE_NET_CIM_NAMESPACE = 'AnetApi/xml/v1/schema/AnetApiSchema.xsd'

      CIM_ACTIONS = {
        :create_customer_profile => 'createCustomerProfile',
        :create_customer_payment_profile => 'createCustomerPaymentProfile',
        :create_customer_shipping_address => 'createCustomerShippingAddress',
        :get_customer_profile => 'getCustomerProfile',
        :get_customer_payment_profile => 'getCustomerPaymentProfile',
        :get_customer_shipping_address => 'getCustomerShippingAddress',
        :delete_customer_profile => 'deleteCustomerProfile',
        :delete_customer_payment_profile => 'deleteCustomerPaymentProfile',
        :delete_customer_shipping_address => 'deleteCustomerShippingAddress',
        :update_customer_profile => 'updateCustomerProfile',
        :update_customer_payment_profile => 'updateCustomerPaymentProfile',
        :update_customer_shipping_address => 'updateCustomerShippingAddress',
        :create_customer_profile_transaction => 'createCustomerProfileTransaction',
        :validate_customer_payment_profile => 'validateCustomerPaymentProfile'
      }
      
      CIM_TRANSACTION_TYPES = {
        :auth_capture => 'profileTransAuthCapture',
        :auth_only => 'profileTransAuthOnly',
        :capture_only => 'profileTransCaptureOnly'
      }

      CIM_VALIDATION_MODES = {
        :none => 'none',
        :test => 'testMode',
        :live => 'liveMode'
      }
      
      BANK_ACCOUNT_TYPES = {
        :checking => 'checking',
        :savings => 'savings',
        :business_checking => 'businessChecking'
      }
      
      ECHECK_TYPES = {
        :ccd => 'CCD',
        :ppd => 'PPD'
      }
      
      self.homepage_url = 'http://www.authorize.net/'
      self.display_name = 'Authorize.Net CIM'
      self.supported_countries = ['US']
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
    
      # Creates a new AuthorizeNetCimGateway
      #
      # The gateway requires that a valid API Login ID and Transaction Key be passed
      # in the +options+ hash.
      #
      # ==== Options
      #
      # * <tt>:login</tt> -- The Authorize.Net API Login ID (REQUIRED)
      # * <tt>:password</tt> -- The Authorize.Net Transaction Key. (REQUIRED)
      # * <tt>:test</tt> -- +true+ or +false+. If true, perform transactions against the test server. 
      #   Otherwise, perform transactions against the production server.
      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options
        super
      end

      # Creates a new customer profile along with any customer payment profiles and customer shipping addresses
      # for the customer profile.
      # 
      # Returns a Response with the Customer Profile ID of the new customer profile in the authorization field. 
      # It is *CRITICAL* that you save this ID. There is no way to retrieve this through the API. You will not 
      # be able to create another Customer Profile with the same information.
      #
      # ==== Options
      #
      # TODO
      def create_customer_profile(options)
        # TODO Add requires
        request = build_request(:create_customer_profile, options)
        commit(:create_customer_profile, request)
      end

      # Creates a new customer payment profile for an existing customer profile.
      #
      # ==== Options
      #
      # * <tt>:customer_profile_id</tt> -- The Customer Profile ID of the customer the payment profile will be added to. (REQUIRED)
      # * <tt>:payment_profile</tt> -- A hash containing the elements of the new payment profile (REQUIRED)
      #
      # ==== Payment Profile
      #
      # * <tt>:payment</tt> -- A hash containing information on payment. Either :credit_card or :bank_account (REQUIRED)
      def create_customer_payment_profile(options)
        requires!(options, :customer_profile_id)
        requires!(options, :payment_profile)
        requires!(options[:payment_profile], :payment)
        
        request = build_request(:create_customer_payment_profile, options)
        commit(:create_customer_payment_profile, request)
      end

      # Creates a new customer shipping address for an existing customer profile.
      #
      # ==== Options
      #
      # * <tt>:customer_profile_id</tt> -- The Customer Profile ID of the customer the payment profile will be added to. (REQUIRED)
      # * <tt>:address</tt> -- A hash containing the elements of the shipping address (REQUIRED)
      def create_customer_shipping_address(options)
        requires!(options, :customer_profile_id)
        requires!(options, :address)
        
        request = build_request(:create_customer_shipping_address, options)
        commit(:create_customer_shipping_address, request)
      end

      # Deletes an existing customer profile along with all associated customer payment profiles and customer shipping addresses.
      #
      # ==== Options
      #
      # * <tt>:customer_profile_id</tt> -- The Customer Profile ID of the customer to be deleted. (REQUIRED)
      def delete_customer_profile(options)
        requires!(options, :customer_profile_id)

        request = build_request(:delete_customer_profile, options)
        commit(:delete_customer_profile, request)
      end

      # Deletes a customer payment profile from an existing customer profile.
      #
      # ==== Options
      #
      # * <tt>:customer_profile_id</tt> -- The Customer Profile ID of the customer with the payment profile to be deleted. (REQUIRED)
      # * <tt>:customer_payment_profile_id</tt> -- The Payment Profile ID of the payment profile to be deleted. (REQUIRED)
      def delete_customer_payment_profile(options)
        requires!(options, :customer_profile_id)
        requires!(options, :customer_payment_profile_id)

        request = build_request(:delete_customer_payment_profile, options)
        commit(:delete_customer_payment_profile, request)
      end

      # Deletes a customer shipping address from an existing customer profile.
      #
      # ==== Options
      #
      # * <tt>:customer_profile_id</tt> -- The Customer Profile ID of the customer with the payment profile to be deleted. (REQUIRED)
      # * <tt>:customer_address_id</tt> -- The Shipping Address ID of the shipping address to be deleted. (REQUIRED)
      def delete_customer_shipping_address(options)
        requires!(options, :customer_profile_id)
        requires!(options, :customer_address_id)

        request = build_request(:delete_customer_shipping_address, options)
        commit(:delete_customer_shipping_address, request)
      end

      # Retrieves an existing customer profile along with all the associated customer payment profiles and customer shipping addresses.
      #
      # Returns a Response whose params hash contains all the profile information.
      #
      # ==== Options
      #
      # * <tt>:customer_profile_id</tt> -- The Customer Profile ID of the customer to retrieve. (REQUIRED)
      def get_customer_profile(options)
        requires!(options, :customer_profile_id)

        request = build_request(:get_customer_profile, options)
        commit(:get_customer_profile, request)
      end

      # Retrieve a customer payment profile for an existing customer profile.
      #
      # Returns a Response whose params hash contains all the payment profile information. Sensitive information such as credit card 
      # numbers will be masked.
      # 
      # ==== Options
      #
      # * <tt>:customer_profile_id</tt> -- The Customer Profile ID of the customer with the payment profile to be retrieved. (REQUIRED)
      # * <tt>:customer_payment_profile_id</tt> -- The Payment Profile ID of the payment profile to be retrieved. (REQUIRED)
      def get_customer_payment_profile(options)
        requires!(options, :customer_profile_id)
        requires!(options, :customer_payment_profile_id)

        request = build_request(:get_customer_payment_profile, options)
        commit(:get_customer_payment_profile, request)
      end

      # Retrieve a customer shipping address for an existing customer profile.
      #
      # Returns a Response whose params hash contains all the shipping address information. 
      # 
      # ==== Options
      #
      # * <tt>:customer_profile_id</tt> -- The Customer Profile ID of the customer with the payment profile to be retrieved. (REQUIRED)
      # * <tt>:customer_address_id</tt> -- The Shipping Address ID of the shipping address to be retrieved. (REQUIRED)
      def get_customer_shipping_address(options)
        requires!(options, :customer_profile_id)
        requires!(options, :customer_address_id)

        request = build_request(:get_customer_shipping_address, options)
        commit(:get_customer_shipping_address, request)
      end

      # Updates an existing customer profile. 
      # 
      # Warning: if you do not provide a parameter in the <tt>:payment_profile</tt> hash, it is automatically set to nil at 
      # Authorize.Net. You will most likely want to first get the profile hash using get_customer_profile and then only change the 
      # elements you wish to change.
      #
      # ==== Options
      #
      # * <tt>:profile</tt> -- A hash containing the values the Customer Profile should be updated to. (REQUIRED)
      # 
      # ==== Profile
      #
      # * <tt>:customer_profile_id</tt> -- The Customer Profile ID of the customer profile to update. (REQUIRED)
      def update_customer_profile(options)
        requires!(options, :profile)
        requires!(options[:profile], :customer_profile_id)

        request = build_request(:update_customer_profile, options)
        commit(:update_customer_profile, request)
      end

      # Updates a customer payment profile for an existing customer profile.
      # 
      # Warning: if you do not provide a parameter in the <tt>:payment_profile</tt> hash, it is automatically set to nil at 
      # Authorize.Net. You will most likely want to first get the profile hash using get_customer_payment_profile and then only
      # change the elements you wish to change.
      #
      # ==== Options
      #
      # * <tt>:customer_profile_id</tt> -- The Customer Profile ID of the customer with the payment profile to be updated. (REQUIRED)
      # * <tt>:payment_profile</tt> -- A hash containing the values the Customer Payment Profile should be updated to. (REQUIRED)
      # 
      # ==== Payment Profile
      #
      # * <tt>:customer_payment_profile_id</tt> -- The Customer Payment Profile ID of the Customer Payment Profile to update. (REQUIRED)
      def update_customer_payment_profile(options)
        requires!(options, :customer_profile_id, :payment_profile)
        requires!(options[:payment_profile], :customer_payment_profile_id)

        request = build_request(:update_customer_payment_profile, options)
        commit(:update_customer_payment_profile, request)
      end

      # Updates a customer shipping address for an existing customer profile.
      # 
      # Warning: if you do not provide a parameter in the <tt>:address</tt> hash, it is automatically set to nil at 
      # Authorize.Net. You will most likely want to first get the profile hash using get_customer_shipping_address and then only
      # change the elements you wish to change.
      #
      # ==== Options
      #
      # * <tt>:customer_profile_id</tt> -- The Customer Profile ID of the customer with the payment profile to be updated. (REQUIRED)
      # * <tt>:address</tt> -- A hash containing the values the Customer Shipping Address should be updated to. (REQUIRED)
      # 
      # ==== Address
      #
      # * <tt>:customer_address_id</tt> -- The Customer Address ID of the Customer Payment Profile to update. (REQUIRED)
      def update_customer_shipping_address(options)
        requires!(options, :customer_profile_id, :address)
        requires!(options[:address], :customer_address_id)

        request = build_request(:update_customer_shipping_address, options)
        commit(:update_customer_shipping_address, request)
      end

      # Creates a new payment transaction from an existing customer profile
      #
      # This is what is used to charge a customer whose information you have stored in a Customer Profile.
      # 
      # Returns a Response object that contains the result of the transaction in <tt>params['direct_response']</tt>
      #
      # ==== Options
      #
      # * <tt>:transaction</tt> -- A hash containing information on the transaction that is being requested. (REQUIRED)
      #
      # ==== Transaction
      #
      # * <tt>:type</tt> -- The type of transaction. Can be either <tt>:auth_only</tt>, <tt>:capture_only</tt>, or <tt>:auth_capture</tt>. (REQUIRED)
      # * <tt>:amount</tt> -- The amount for the tranaction. Formatted with a decimal. For example "4.95" (REQUIRED)
      # * <tt>:customer_profile_id</tt> -- The Customer Profile ID of the customer to use in this transaction. (REQUIRED)
      # * <tt>:customer_payment_profile_id</tt> -- The Customer Payment Profile ID of the Customer Payment Profile to use in this transaction. (REQUIRED)
      def create_customer_profile_transaction(options)
        requires!(options, :transaction)
        requires!(options[:transaction], :type, :amount, :customer_profile_id, :customer_payment_profile_id)

        request = build_request(:create_customer_profile_transaction, options)
        commit(:create_customer_profile_transaction, request)
      end

      # Verifies an existing customer payment profile by generating a test transaction
      #
      # Returns a Response object that contains the result of the transaction in <tt>params['direct_response']</tt>
      #
      # ==== Options
      #
      # * <tt>:customer_profile_id</tt> -- The Customer Profile ID of the customer to use in this transaction. (REQUIRED)
      # * <tt>:customer_payment_profile_id</tt> -- The Customer Payment Profile ID of the Customer Payment Profile to be verified. (REQUIRED)
      # * <tt>:customer_address_id</tt> -- The Customer Address ID of the Customer Shipping Address to be verified.
      # * <tt>:validation_mode</tt> -- <tt>:live</tt> or <tt>:test</tt> In Test Mode, only field validation is performed. 
      #   In Live Mode, a transaction is generated and submitted to the processor with the amount of $0.01. If successful, the transaction is immediately voided. (REQUIRED)
      def validate_customer_payment_profile(options)
        requires!(options, :customer_profile_id, :customer_payment_profile_id, :validation_mode)

        request = build_request(:validate_customer_payment_profile, options)
        commit(:validate_customer_payment_profile, request)
      end

      private

      def expdate(credit_card)
        sprintf('%04d-%02d', credit_card.year, credit_card.month)
      end
      
      def build_request(action, options = {})
        unless CIM_ACTIONS.include?(action)
          raise StandardError, "Invalid Customer Information Manager Action: #{action}"
        end

        xml = Builder::XmlMarkup.new(:indent => 2)
        xml.instruct!(:xml, :version => '1.0', :encoding => 'utf-8')
        xml.tag!("#{CIM_ACTIONS[action]}Request", :xmlns => AUTHORIZE_NET_CIM_NAMESPACE) do
          add_merchant_authentication(xml)
          # Merchant-assigned reference ID for the request
          xml.tag!('refId', options[:ref_id]) if options[:ref_id]
          send("build_#{action}_request", xml, options)
        end
      end

      # Contains the merchant’s payment gateway account authentication information
      def add_merchant_authentication(xml)
        xml.tag!('merchantAuthentication') do
          xml.tag!('name', @options[:login])
          xml.tag!('transactionKey', @options[:password])
        end
      end
      
      def build_create_customer_profile_request(xml, options)
        add_profile(xml, options[:profile])

        xml.target!
      end

      def build_create_customer_payment_profile_request(xml, options)
        xml.tag!('customerProfileId', options[:customer_profile_id])
        
        xml.tag!('paymentProfile') do
          add_payment_profile(xml, options[:payment_profile])
        end
        
        xml.tag!('validationMode', CIM_VALIDATION_MODES[options[:validation_mode]]) if options[:validation_mode]

        xml.target!
      end
      
      def build_create_customer_shipping_address_request(xml, options)
        xml.tag!('customerProfileId', options[:customer_profile_id])
        
        xml.tag!('address') do
          add_address(xml, options[:address])
        end
        
        xml.target!
      end

      def build_delete_customer_profile_request(xml, options)
        xml.tag!('customerProfileId', options[:customer_profile_id])
        xml.target!
      end

      def build_delete_customer_payment_profile_request(xml, options)
        xml.tag!('customerProfileId', options[:customer_profile_id])
        xml.tag!('customerPaymentProfileId', options[:customer_payment_profile_id])
        xml.target!
      end

      def build_delete_customer_shipping_address_request(xml, options)
        xml.tag!('customerProfileId', options[:customer_profile_id])
        xml.tag!('customerAddressId', options[:customer_address_id])
        xml.target!
      end

      def build_get_customer_profile_request(xml, options)
        xml.tag!('customerProfileId', options[:customer_profile_id])
        xml.target!
      end

      def build_get_customer_payment_profile_request(xml, options)
        xml.tag!('customerProfileId', options[:customer_profile_id])
        xml.tag!('customerPaymentProfileId', options[:customer_payment_profile_id])
        xml.target!
      end

      def build_get_customer_shipping_address_request(xml, options)
        xml.tag!('customerProfileId', options[:customer_profile_id])
        xml.tag!('customerAddressId', options[:customer_address_id])
        xml.target!
      end

      def build_update_customer_profile_request(xml, options)
        add_profile(xml, options[:profile], true) 
        
        xml.target!
      end

      def build_update_customer_payment_profile_request(xml, options)
        xml.tag!('customerProfileId', options[:customer_profile_id])

        xml.tag!('paymentProfile') do
          add_payment_profile(xml, options[:payment_profile]) 
        end

        xml.target!
      end

      def build_update_customer_shipping_address_request(xml, options)
        xml.tag!('customerProfileId', options[:customer_profile_id])

        xml.tag!('address') do
          add_address(xml, options[:address]) 
        end

        xml.target!
      end

      def build_create_customer_profile_transaction_request(xml, options)
        add_transaction(xml, options[:transaction])
        
        xml.target!
      end
      
      def build_validate_customer_payment_profile_request(xml, options)
        xml.tag!('customerProfileId', options[:customer_profile_id])
        xml.tag!('customerPaymentProfileId', options[:customer_payment_profile_id])
        xml.tag!('customerShippingAddressId', options[:customer_address_id]) if options[:customer_address_id]
        xml.tag!('validationMode', CIM_VALIDATION_MODES[options[:validation_mode]]) if options[:validation_mode]

        xml.target!
      end

      # :merchant_customer_id (Optional)
      # :description (Optional)
      # :email (Optional)
      # :payment_profiles (Optional)
      def add_profile(xml, profile, update = false)
        xml.tag!('profile') do
          # Merchant assigned ID for the customer. Up to 20 characters. (optional)
          xml.tag!('merchantCustomerId', profile[:merchant_customer_id]) if profile[:merchant_customer_id]
          # Description of the customer. Up to 255 Characters (optional)
          xml.tag!('description', profile[:description]) if profile[:description]
          # Email Address for the customer. Up to 255 Characters (optional)
          xml.tag!('email', profile[:email]) if profile[:email]

          if update
            xml.tag!('customerProfileId', profile[:customer_profile_id])
          else
            add_payment_profiles(xml, profile[:payment_profiles]) if profile[:payment_profiles]
            add_ship_to_list(xml, profile[:ship_to_list]) if profile[:ship_to_list]
          end
        end
      end
      
      def add_transaction(xml, transaction)
        unless CIM_TRANSACTION_TYPES.include?(transaction[:type])
          raise StandardError, "Invalid Customer Information Manager Transaction Type: #{transaction[:type]}"
        end
        
        xml.tag!('transaction') do
          xml.tag!(CIM_TRANSACTION_TYPES[transaction[:type]]) do
            # The amount to be billed to the customer
            xml.tag!('amount', transaction[:amount])
            xml.tag!('customerProfileId', transaction[:customer_profile_id])
            xml.tag!('customerPaymentProfileId', transaction[:customer_payment_profile_id])
            xml.tag!('approvalCode', transaction[:approval_code]) if transaction[:type] == :capture_only
            add_order(xml, transaction[:order]) if transaction[:order]
          end
        end
      end
      
      def add_order(xml, order)
        xml.tag!('order') do
          xml.tag!('invoiceNumber', order[:invoice_number]) if order[:invoice_number]
          xml.tag!('description', order[:description]) if order[:description]
          xml.tag!('purchaseOrderNumber', order[:purchase_order_number]) if order[:purchase_order_number]
        end
      end
      
      def add_payment_profiles(xml, payment_profiles)
        xml.tag!('paymentProfiles') do
          add_payment_profile(xml, payment_profiles)
        end
      end

      # :customer_type => 'individual or business', # Optional
      # :bill_to => @address,
      # :payment => @payment
      def add_payment_profile(xml, payment_profile)
        # 'individual' or 'business' (optional)
        xml.tag!('customerType', payment_profile[:customer_type]) if payment_profile[:customer_type]

        if payment_profile[:bill_to]
          xml.tag!('billTo') do
            add_address(xml, payment_profile[:bill_to])
          end
        end
        
        if payment_profile[:payment]
          xml.tag!('payment') do
            add_credit_card(xml, payment_profile[:payment][:credit_card]) if payment_profile[:payment].has_key?(:credit_card)
            add_bank_account(xml, payment_profile[:payment][:bank_account]) if payment_profile[:payment].has_key?(:bank_account)
            add_drivers_license(xml, payment_profile[:payment][:drivers_license]) if payment_profile[:payment].has_key?(:drivers_license)
            # This element is only required for Wells Fargo SecureSource eCheck.Net merchants
            # The customer's Social Security Number or Tax ID
            xml.tag!('taxId', payment_profile[:payment]) if payment_profile[:payment].has_key?(:tax_id)
          end
        end
        
        xml.tag!('customerPaymentProfileId', payment_profile[:customer_payment_profile_id]) if payment_profile[:customer_payment_profile_id]
      end

      def add_ship_to_list(xml, ship_to_list)
        xml.tag!('shipToList') do
          add_address(xml, ship_to_list)
        end
      end

      def add_address(xml, address)
        xml.tag!('firstName', address[:first_name])
        xml.tag!('lastName', address[:last_name])
        xml.tag!('company', address[:company])
        xml.tag!('address', address[:address1]) if address[:address1]
        xml.tag!('address', address[:address]) if address[:address]
        xml.tag!('city', address[:city])
        xml.tag!('state', address[:state])
        xml.tag!('zip', address[:zip])
        xml.tag!('country', address[:country])
        xml.tag!('phoneNumber', address[:phone_number]) if address[:phone_number]
        xml.tag!('faxNumber', address[:fax_number]) if address[:fax_number]
        
        xml.tag!('customerAddressId', address[:customer_address_id]) if address[:customer_address_id]
      end

      # Adds customer’s credit card information
      # Note: This element should only be included
      # when the payment method is credit card.
      def add_credit_card(xml, credit_card)
        return unless credit_card
        xml.tag!('creditCard') do
          # The credit card number used for payment of the subscription
          xml.tag!('cardNumber', credit_card.number)
          # The expiration date of the credit card used for the subscription
          xml.tag!('expirationDate', expdate(credit_card))
          xml.tag!('cardCode', credit_card.verification_value) if credit_card.verification_value?
        end
      end
      
      # Adds customer’s bank account information
      # Note: This element should only be included 
      # when the payment method is bank account.
      def add_bank_account(xml, bank_account)
        raise StandardError, "Invalid Bank Account Type: #{bank_account[:account_type]}" unless BANK_ACCOUNT_TYPES.include?(bank_account[:account_type])
        raise StandardError, "Invalid eCheck Type: #{bank_account[:echeck_type]}" unless ECHECK_TYPES.include?(bank_account[:echeck_type])
        
        xml.tag!('bankAccount') do
          # The type of bank account
          xml.tag!('accountType', BANK_ACCOUNT_TYPES[bank_account[:account_type]])
          # The routing number of the customer’s bank
          xml.tag!('routingNumber', bank_account[:routing_number])
          # The bank account number
          xml.tag!('accountNumber', bank_account[:account_number])
          # The full name of the individual associated 
          # with the bank account number
          xml.tag!('nameOnAccount', bank_account[:name_on_account])
          # The type of electronic check transaction
          xml.tag!('echeckType', ECHECK_TYPES[bank_account[:echeck_type]])
          # The full name of the individual associated 
          # with the bank account number (optional)
          xml.tag!('bankName', bank_account[:bank_name]) if bank_account[:bank_name]
        end
      end
      
      # Adds customer’s driver's license information
      # Note: This element is only required for 
      # Wells Fargo SecureSource eCheck.Net merchants
      def add_drivers_license(xml, drivers_license)
        xml.tag!('driversLicense') do
          # The state of the customer's driver's license
          # A valid two character state code
          xml.tag!('state', drivers_license[:state])
          # The customer’s driver's license number
          xml.tag!('number', drivers_license[:number])
          # The date of birth listed on the customer's driver's license
          # YYYY-MM-DD
          xml.tag!('dateOfBirth', drivers_license[:date_of_birth])
        end
      end
      
      def commit(action, request)
        url = test? ? test_url : live_url
        xml = ssl_post(url, request, "Content-Type" => "text/xml")
        
        response_params = parse(action, xml)

        message = response_params['messages']['message']['text']
        test_mode = test? || message =~ /Test Mode/
        success = response_params['messages']['result_code'] == 'Ok'

        response = Response.new(success, message, response_params,
          :test => test_mode,
          :authorization => response_params['customer_profile_id'] || (response_params['profile'] ? response_params['profile']['customer_profile_id'] : nil)
        )
        
        response.params['direct_response'] = parse_direct_response(response) if response.params['direct_response']
        response
      end
      
      def parse_direct_response(response)
        direct_response = {'raw' => response.params['direct_response']}
        direct_response_fields = response.params['direct_response'].split(',')

        direct_response.merge(
          {
            'approval_code' => direct_response_fields[4],
            'message' => direct_response_fields[3],
            'transaction_type' => direct_response_fields[11],
            'amount' => direct_response_fields[9],
            'invoice_number' => direct_response_fields[7],
            'order_description' => direct_response_fields[8],
            'purchase_order_number' => direct_response_fields[36]
            # TODO fill in other fields
          }
        )
      end
      
      def parse(action, xml)
        xml = REXML::Document.new(xml)
        root = REXML::XPath.first(xml, "//#{CIM_ACTIONS[action]}Response") ||
               REXML::XPath.first(xml, "//ErrorResponse")
        if root
          response = parse_element(root)
        end

        response
      end

      def parse_element(node)
        if node.has_elements?
          response = {}
          node.elements.each{ |e|
            key = e.name.underscore
            value = parse_element(e)
            if response.has_key?(key)
              if response[key].is_a?(Array)
                response[key].push(value)
              else
                response[key] = [response[key], value]
              end
            else
              response[key] = parse_element(e) 
            end 
          }
        else
          response = node.text
        end

        response
      end
    end
  end
end
