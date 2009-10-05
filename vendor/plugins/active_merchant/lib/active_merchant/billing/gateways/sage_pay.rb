module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SagePayGateway < Gateway  
      cattr_accessor :simulate
      self.simulate = false
      
      TEST_URL = 'https://test.sagepay.com/gateway/service'
      LIVE_URL = 'https://live.sagepay.com/gateway/service'
      SIMULATOR_URL = 'https://test.sagepay.com/Simulator'
      
      APPROVED = 'OK'
    
      TRANSACTIONS = {
        :purchase => 'PAYMENT',
        :credit => 'REFUND',
        :authorization => 'DEFERRED',
        :capture => 'RELEASE',
        :void => 'VOID',
        :abort => 'ABORT'
      }
      
      CREDIT_CARDS = {
        :visa => "VISA",
        :master => "MC",
        :delta => "DELTA",
        :solo => "SOLO",
        :switch => "MAESTRO",
        :maestro => "MAESTRO",
        :american_express => "AMEX",
        :electron => "UKE",
        :diners_club => "DC",
        :jcb => "JCB"
      }
      
      ELECTRON = /^(424519|42496[23]|450875|48440[6-8]|4844[1-5][1-5]|4917[3-5][0-9]|491880)\d{10}(\d{3})?$/
      
      AVS_CVV_CODE = {
        "NOTPROVIDED" => nil, 
        "NOTCHECKED" => 'X',
        "MATCHED" => 'Y',
        "NOTMATCHED" => 'N'
      }
    
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :jcb, :switch, :solo, :maestro, :diners_club]
      self.supported_countries = ['GB']
      self.default_currency = 'GBP'
      
      self.homepage_url = 'http://www.sagepay.com'
      self.display_name = 'SagePay'

      def initialize(options = {})
        requires!(options, :login)
        @options = options
        super
      end
      
      def test?
        @options[:test] || super
      end
      
      def purchase(money, credit_card, options = {})
        requires!(options, :order_id)
        
        post = {}
        
        add_amount(post, money, options)
        add_invoice(post, options)
        add_credit_card(post, credit_card)
        add_address(post, options)
        add_customer_data(post, options)

        commit(:purchase, post)
      end
      
      def authorize(money, credit_card, options = {})
        requires!(options, :order_id)
        
        post = {}
        
        add_amount(post, money, options)
        add_invoice(post, options)
        add_credit_card(post, credit_card)
        add_address(post, options)
        add_customer_data(post, options)

        commit(:authorization, post)
      end
      
      # You can only capture a transaction once, even if you didn't capture the full amount the first time.
      def capture(money, identification, options = {})
        post = {}
        
        add_reference(post, identification)
        add_release_amount(post, money, options)
        
        commit(:capture, post)
      end
      
      def void(identification, options = {})
        post = {}
        
        add_reference(post, identification)
        action = abort_or_void_from(identification)

        commit(action, post)
      end

      # Crediting requires a new order_id to passed in, as well as a description
      def credit(money, identification, options = {})
        requires!(options, :order_id, :description)
        
        post = {}
        
        add_credit_reference(post, identification)
        add_amount(post, money, options)
        add_invoice(post, options)
        
        commit(:credit, post)
      end
      
      private
      def add_reference(post, identification)
        order_id, transaction_id, authorization, security_key = identification.split(';') 
        
        add_pair(post, :VendorTxCode, order_id)
        add_pair(post, :VPSTxId, transaction_id)
        add_pair(post, :TxAuthNo, authorization)
        add_pair(post, :SecurityKey, security_key)
      end
      
      def add_credit_reference(post, identification)
        order_id, transaction_id, authorization, security_key = identification.split(';') 
        
        add_pair(post, :RelatedVendorTxCode, order_id)
        add_pair(post, :RelatedVPSTxId, transaction_id)
        add_pair(post, :RelatedTxAuthNo, authorization)
        add_pair(post, :RelatedSecurityKey, security_key)
      end
      
      def add_amount(post, money, options)
        add_pair(post, :Amount, amount(money), :required => true)
        add_pair(post, :Currency, options[:currency] || currency(money), :required => true)
      end

      # doesn't actually use the currency -- dodgy!
      def add_release_amount(post, money, options)
        add_pair(post, :ReleaseAmount, amount(money), :required => true)
      end

      def add_customer_data(post, options)
        add_pair(post, :CustomerEMail, options[:email][0,255]) unless options[:email].blank?
        add_pair(post, :BillingPhone, options[:phone].gsub(/[^0-9+]/, '')[0,20]) unless options[:phone].blank?
        add_pair(post, :ClientIPAddress, options[:ip])
      end

      def add_address(post, options)
        if billing_address = options[:billing_address] || options[:address]
          first_name, last_name = parse_first_and_last_name(billing_address[:name])
          add_pair(post, :BillingSurname, last_name)
          add_pair(post, :BillingFirstnames, first_name)
          add_pair(post, :BillingAddress1, billing_address[:address1])
          add_pair(post, :BillingAddress2, billing_address[:address2])
          add_pair(post, :BillingCity, billing_address[:city])
          add_pair(post, :BillingState, billing_address[:state]) if billing_address[:country] == 'US'
          add_pair(post, :BillingCountry, billing_address[:country])
          add_pair(post, :BillingPostCode, billing_address[:zip])
        end
        
        if shipping_address = options[:shipping_address] || billing_address
          first_name, last_name = parse_first_and_last_name(shipping_address[:name])
          add_pair(post, :DeliverySurname, last_name)
          add_pair(post, :DeliveryFirstnames, first_name)
          add_pair(post, :DeliveryAddress1, shipping_address[:address1])
          add_pair(post, :DeliveryAddress2, shipping_address[:address2])
          add_pair(post, :DeliveryCity, shipping_address[:city])
          add_pair(post, :DeliveryState, shipping_address[:state]) if shipping_address[:country] == 'US'
          add_pair(post, :DeliveryCountry, shipping_address[:country])
          add_pair(post, :DeliveryPostCode, shipping_address[:zip])
        end
      end

      def add_invoice(post, options)
        add_pair(post, :VendorTxCode, sanitize_order_id(options[:order_id]), :required => true)
        add_pair(post, :Description, options[:description] || options[:order_id])
      end

      def add_credit_card(post, credit_card)
        add_pair(post, :CardHolder, credit_card.name, :required => true)
        add_pair(post, :CardNumber, credit_card.number, :required => true)
         
        add_pair(post, :ExpiryDate, format_date(credit_card.month, credit_card.year), :required => true)
         
        if requires_start_date_or_issue_number?(credit_card)
          add_pair(post, :StartDate, format_date(credit_card.start_month, credit_card.start_year))
          add_pair(post, :IssueNumber, credit_card.issue_number)
        end
        add_pair(post, :CardType, map_card_type(credit_card))
        
        add_pair(post, :CV2, credit_card.verification_value)
      end
      
      def sanitize_order_id(order_id)
        order_id.to_s.gsub(/[^-a-zA-Z0-9._]/, '')
      end
      
      def map_card_type(credit_card)
        raise ArgumentError, "The credit card type must be provided" if card_brand(credit_card).blank?
        
        card_type = card_brand(credit_card).to_sym
        
        # Check if it is an electron card
        if card_type == :visa && credit_card.number =~ ELECTRON 
          CREDIT_CARDS[:electron]
        else  
          CREDIT_CARDS[card_type]
        end
      end
      
      # MMYY format
      def format_date(month, year)
        return nil if year.blank? || month.blank?
        
        year  = sprintf("%.4i", year)
        month = sprintf("%.2i", month)

        "#{month}#{year[-2..-1]}"
      end
      
      def commit(action, parameters)
        response = parse( ssl_post(url_for(action), post_data(action, parameters)) )
          
        Response.new(response["Status"] == APPROVED, message_from(response), response,
          :test => test?,
          :authorization => authorization_from(response, parameters, action),
          :avs_result => { 
            :street_match => AVS_CVV_CODE[ response["AddressResult"] ],
            :postal_match => AVS_CVV_CODE[ response["PostCodeResult"] ],
          },
          :cvv_result => AVS_CVV_CODE[ response["CV2Result"] ]
        )
      end
      
      def authorization_from(response, params, action)
         [ params[:VendorTxCode],
           response["VPSTxId"],
           response["TxAuthNo"],
           response["SecurityKey"],
           action ].join(";")
      end

      def abort_or_void_from(identification)
        original_transaction = identification.split(';').last
        original_transaction == 'authorization' ? :abort : :void
      end

      def url_for(action)
        simulate ? build_simulator_url(action) : build_url(action)
      end
      
      def build_url(action)
        endpoint = [ :purchase, :authorization ].include?(action) ? "vspdirect-register" : TRANSACTIONS[action].downcase
        "#{test? ? TEST_URL : LIVE_URL}/#{endpoint}.vsp"
      end
      
      def build_simulator_url(action)
        endpoint = [ :purchase, :authorization ].include?(action) ? "VSPDirectGateway.asp" : "VSPServerGateway.asp?Service=Vendor#{TRANSACTIONS[action].capitalize}Tx"
        "#{SIMULATOR_URL}/#{endpoint}"
      end

      def message_from(response)
        response['Status'] == APPROVED ? 'Success' : (response['StatusDetail'] || 'Unspecified error')    # simonr 20080207 can't actually get non-nil blanks, so this is shorter
      end

      def post_data(action, parameters = {})
        parameters.update(
          :Vendor => @options[:login],
          :TxType => TRANSACTIONS[action],
          :VPSProtocol => "2.23"
        )
        
        parameters.collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
      end
      
      # SagePay returns data in the following format
      # Key1=value1
      # Key2=value2
      def parse(body)
        result = {}
        body.to_a.each { |pair| result[$1] = $2 if pair.strip =~ /\A([^=]+)=(.+)\Z/im }
        result
      end

      def add_pair(post, key, value, options = {})
        post[key] = value if !value.blank? || options[:required]
      end

      def parse_first_and_last_name(value)
        name = value.to_s.split(' ')
        
        last_name = name.pop || ''
        first_name = name.join(' ')
        [ first_name[0,20], last_name[0,20] ]
      end
    end
    ProtxGateway = SagePayGateway
  end
end

