# Authors::    MoneySpyder, http://moneyspyder.co.uk and E-consultancy, http://www.e-consultancy.com

module ActiveMerchant
  module Billing
    class DataCashGateway < Gateway
      self.default_currency = 'GBP'
      self.supported_countries = ['GB']

      # From the DataCash docs; Page 13, the following cards are
      # usable:
      # American Express, ATM, Carte Blanche, Diners Club, Discover,
      # EnRoute, GE Capital, JCB, Laser, Maestro, Mastercard, Solo,
      # Switch, Visa, Visa Delta, VISA Electron, Visa Purchasing 
      #
      # Note continuous authority is only supported for :visa, :master and :american_express card types  
      self.supported_cardtypes = [ :visa, :master, :american_express, :discover, :diners_club, :jcb, :maestro, :switch, :solo, :laser ]

      self.homepage_url = 'http://www.datacash.com/'
      self.display_name = 'DataCash'

      # Datacash server URLs
      TEST_URL = 'https://testserver.datacash.com/Transaction'
      LIVE_URL = 'https://mars.transaction.datacash.com/Transaction'

      # Different Card Transaction Types
      AUTH_TYPE = 'auth'
      CANCEL_TYPE = 'cancel'
      FULFILL_TYPE = 'fulfill'
      PRE_TYPE = 'pre'
      REFUND_TYPE = 'refund'
      TRANSACTION_REFUND_TYPE = 'txn_refund'

      # Constant strings for use in the ExtendedPolicy complex element for
      # CV2 checks
      POLICY_ACCEPT = 'accept'
      POLICY_REJECT = 'reject'

      # Datacash success code
      DATACASH_SUCCESS = '1'

      # Creates a new DataCashGateway
      # 
      # The gateway requires that a valid login and password be passed
      # in the +options+ hash.
      # 
      # ==== Options
      #
      # * <tt>:login</tt> -- The Datacash account login.
      # * <tt>:password</tt> -- The Datacash account password.
      # * <tt>:test => +true+ or +false+</tt> -- Use the test or live Datacash url.
      #     
      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options
        super
      end

      # Perform a purchase, which is essentially an authorization and capture in a single operation.
      # 
      # ==== Parameters
      # * <tt>money</tt> The amount to be authorized.  Either an Integer value in cents or a Money object.
      # * <tt>authorization_or_credit_card</tt>:: The continuous authority reference or CreditCard details for the transaction.
      # * <tt>options</tt> A hash of optional parameters.
      #   * <tt>:order_id</tt> A unique reference for this order (corresponds to merchantreference in datacash documentation)
      #   * <tt>:set_up_continuous_authority</tt>
      #      Set to true to set up a recurring historic transaction account be set up.
      #      Only supported for :visa, :master and :american_express card types 
      #      See http://www.datacash.com/services/recurring/historic.php for more details of historic transactions. 
      #   * <tt>:address</tt>:: billing address for card
      #
      # The continuous authority reference will be available in response#params['ca_referece'] if you have requested one
      def purchase(money, authorization_or_credit_card, options = {})
        requires!(options, :order_id)

        if authorization_or_credit_card.is_a?(String)
          request = build_purchase_or_authorization_request_with_continuous_authority_reference_request(AUTH_TYPE, money, authorization_or_credit_card, options)
        else
          request = build_purchase_or_authorization_request_with_credit_card_request(AUTH_TYPE, money, authorization_or_credit_card, options)
        end

        commit(request)
      end

      # Performs an authorization, which reserves the funds on the customer's credit card, but does not 
      # charge the card.
      #
      # ==== Parameters
      #
      # * <tt>money</tt> The amount to be authorized.  Either an Integer value in cents or a Money object.
      # * <tt>authorization_or_credit_card</tt>:: The continuous authority reference or CreditCard details for the transaction.
      # * <tt>options</tt> A hash of optional parameters.
      #   * <tt>:order_id</tt> A unique reference for this order (corresponds to merchantreference in datacash documentation)
      #   * <tt>:set_up_continuous_authority</tt>::
      #      Set to true to set up a recurring historic transaction account be set up.
      #      Only supported for :visa, :master and :american_express card types 
      #      See http://www.datacash.com/services/recurring/historic.php for more details of historic transactions. 
      #   * <tt>:address</tt>:: billing address for card
      #
      # The continuous authority reference will be available in response#params['ca_referece'] if you have requested one
      def authorize(money, authorization_or_credit_card, options = {})
        requires!(options, :order_id)

        if authorization_or_credit_card.is_a?(String)
          request = build_purchase_or_authorization_request_with_continuous_authority_reference_request(AUTH_TYPE, money, authorization_or_credit_card, options)
        else
          request = build_purchase_or_authorization_request_with_credit_card_request(PRE_TYPE, money, authorization_or_credit_card, options)
        end

        commit(request)
      end

      # Captures the funds from an authorized transaction.
      # 
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be captured.  Either an Integer value in cents or a Money object.
      # * <tt>authorization</tt> -- The authorization returned from the previous authorize request.   
      def capture(money, authorization, options = {})
        commit(build_void_or_capture_request(FULFILL_TYPE, money, authorization, options))
      end                    

      # Void a previous transaction
      # 
      # ==== Parameters
      #
      # * <tt>authorization</tt> - The authorization returned from the previous authorize request.   
      def void(authorization, options = {})
        request = build_void_or_capture_request(CANCEL_TYPE, nil, authorization, options)

        commit(request)
      end

      # Refund to a card
      # 
      # ==== Parameters
      #
      # * <tt>money</tt> The amount to be refunded. Either an Integer value in cents or a Money object. Set to nil for a full refund on existing transaction.
      # * <tt>reference_or_credit_card</tt> The credit card you want to refund OR the datacash_reference for the existing transaction you are refunding
      # * <tt>options</tt> Are ignored when refunding via reference to an existing transaction, otherwise
      #   * <tt>:order_id</tt> A unique reference for this order (corresponds to merchantreference in datacash documentation)
      #   * <tt>:address</tt>:: billing address for card
      def credit(money, reference_or_credit_card, options = {})
        if reference_or_credit_card.is_a?(String)
          request = build_transaction_refund_request(money, reference_or_credit_card)
        else
          request = build_refund_request(money, reference_or_credit_card, options)
        end

        commit(request)
      end

      # Is the gateway running in test mode?
      def test?
        @options[:test] || super
      end

      private                         
      # Create the xml document for a 'cancel' or 'fulfill' transaction.
      # 
      # Final XML should look like:
      # <Request>
      #  <Authentication>
      #    <client>99000001</client>
      #    <password>******</password>
      #  </Authentication>
      #  <Transaction>
      #    <TxnDetails>
      #      <amount>25.00</amount>
      #    </TxnDetails>
      #    <HistoricTxn>
      #      <reference>4900200000000001</reference>
      #      <authcode>A6</authcode>
      #      <method>fulfill</method>
      #    </HistoricTxn>
      #  </Transaction>
      # </Request>
      # 
      # Parameters:
      # * <tt>type</tt> must be FULFILL_TYPE or CANCEL_TYPE
      # * <tt>money</tt> - optional - Money object or value in cents
      # * <tt>authorization</tt> - the Datacash authorization from a previous succesful authorize transaction
      # * <tt>options</tt>
      #   * <tt>order_id</tt> - A unique reference for the transaction
      #   
      # Returns:
      #   -Builder xml document
      #
      def build_void_or_capture_request(type, money, authorization, options)
        reference, auth_code, ca_reference = authorization.to_s.split(';')

        xml = Builder::XmlMarkup.new :indent => 2
        xml.instruct!
        xml.tag! :Request do
          add_authentication(xml)
          
          xml.tag! :Transaction do
            xml.tag! :HistoricTxn do
              xml.tag! :reference, reference
              xml.tag! :authcode, auth_code
              xml.tag! :method, type
            end
            
            if money
              xml.tag! :TxnDetails do
                xml.tag! :merchantreference, format_reference_number(options[:order_id])
                xml.tag! :amount, amount(money), :currency => options[:currency] || currency(money)
              end
            end
          end
        end
        xml.target!
      end

      # Create the xml document for an 'auth' or 'pre' transaction with a credit card
      # 
      # Final XML should look like:
      # 
      # <Request>
      #  <Authentication>
      #    <client>99000000</client>
      #    <password>*******</password>
      #  </Authentication>
      #  <Transaction>
      #    <TxnDetails>
      #      <merchantreference>123456</merchantreference>
      #      <amount currency="EUR">10.00</amount>
      #    </TxnDetails>
      #    <CardTxn>
      #      <Card>
      #        <pan>4444********1111</pan>
      #        <expirydate>03/04</expirydate>
      #        <Cv2Avs>
      #          <street_address1>Flat 7</street_address1>
      #          <street_address2>89 Jumble
      #               Street</street_address2>
      #          <street_address3>Mytown</street_address3>
      #          <postcode>AV12FR</postcode>
      #          <cv2>123</cv2>
      #           <ExtendedPolicy>
      #             <cv2_policy notprovided="reject"
      #                          notchecked="accept"
      #                          matched="accept"
      #                          notmatched="reject"
      #                          partialmatch="reject"/>
      #             <postcode_policy notprovided="reject"
      #                          notchecked="accept"
      #                          matched="accept"
      #                          notmatched="reject"
      #                          partialmatch="accept"/>
      #             <address_policy notprovided="reject"
      #                          notchecked="accept"
      #                          matched="accept"
      #                          notmatched="reject"
      #                          partialmatch="accept"/>
      #           </ExtendedPolicy>
      #        </Cv2Avs>
      #      </Card>
      #      <method>auth</method>
      #    </CardTxn>
      #  </Transaction>
      # </Request>
      # 
      # Parameters:
      #   -type must be 'auth' or 'pre'
      #   -money - A money object with the price and currency
      #   -credit_card - The credit_card details to use
      #   -options:
      #     :order_id is the merchant reference number
      #     :billing_address is the billing address for the cc
      #     :address is the delivery address
      #   
      # Returns:
      #   -xml: Builder document containing the markup
      #
      def build_purchase_or_authorization_request_with_credit_card_request(type, money, credit_card, options)
        xml = Builder::XmlMarkup.new :indent => 2
        xml.instruct!
        xml.tag! :Request do
          add_authentication(xml)
          
          xml.tag! :Transaction do
            if options[:set_up_continuous_authority]
              xml.tag! :ContAuthTxn, :type => 'setup'
            end
            xml.tag! :CardTxn do
              xml.tag! :method, type
              add_credit_card(xml, credit_card, options[:billing_address])
            end
            xml.tag! :TxnDetails do
              xml.tag! :merchantreference, format_reference_number(options[:order_id])
              xml.tag! :amount, amount(money), :currency => options[:currency] || currency(money)
            end
          end
        end
        xml.target!
      end

      # Create the xml document for an 'auth' or 'pre' transaction with
      # continuous authorization
      # 
      # Final XML should look like:
      # 
      # <Request> 
      #   <Transaction> 
      #     <ContAuthTxn type="historic" /> 
      #     <TxnDetails> 
      #       <merchantreference>3851231</merchantreference> 
      #       <capturemethod>cont_auth</capturemethod> 
      #       <amount currency="GBP">18.50</amount> 
      #     </TxnDetails> 
      #     <HistoricTxn> 
      #       <reference>4500200040925092</reference> 
      #       <method>auth</method> 
      #     </HistoricTxn> 
      #   </Transaction> 
      #   <Authentication> 
      #     <client>99000001</client> 
      #     <password>mypasswd</password> 
      #   </Authentication> 
      # </Request>
      # 
      # Parameters:
      #   -type must be 'auth' or 'pre'
      #   -money - A money object with the price and currency
      #   -authorization - The authorization containing a continuous authority reference previously set up on a credit card
      #   -options:
      #     :order_id is the merchant reference number
      #   
      # Returns:
      #   -xml: Builder document containing the markup
      #
      def build_purchase_or_authorization_request_with_continuous_authority_reference_request(type, money, authorization, options)
        reference, auth_code, ca_reference = authorization.to_s.split(';')
        raise ArgumentError, "The continuous authority reference is required for continuous authority transactions" if ca_reference.blank?

        xml = Builder::XmlMarkup.new :indent => 2
        xml.instruct!
        xml.tag! :Request do
          add_authentication(xml)
          xml.tag! :Transaction do
            xml.tag! :ContAuthTxn, :type => 'historic'
            xml.tag! :HistoricTxn do
              xml.tag! :reference, ca_reference
              xml.tag! :method, type
            end
            xml.tag! :TxnDetails do
              xml.tag! :merchantreference, format_reference_number(options[:order_id])
              xml.tag! :amount, amount(money), :currency => options[:currency] || currency(money)
              xml.tag! :capturemethod, 'cont_auth'
            end
          end
        end
        xml.target!
      end

      # Create the xml document for a full or partial refund transaction with
      # 
      # Final XML should look like:
      #
      # <Request> 
      #   <Authentication> 
      #     <client>99000001</client> 
      #     <password>*******</password> 
      #   </Authentication> 
      #   <Transaction> 
      #     <HistoricTxn> 
      #       <method>txn_refund</method> 
      #       <reference>12345678</reference> 
      #     </HistoricTxn> 
      #     <TxnDetails> 
      #       <amount>10.00</amount> 
      #     </TxnDetails> 
      #   </Transaction>
      # </Request> 
      # 
      def build_transaction_refund_request(money, reference)
        xml = Builder::XmlMarkup.new :indent => 2
        xml.instruct!
        xml.tag! :Request do
          add_authentication(xml)
          xml.tag! :Transaction do
            xml.tag! :HistoricTxn do
              xml.tag! :reference, reference
              xml.tag! :method, TRANSACTION_REFUND_TYPE
            end
            unless money.nil?
              xml.tag! :TxnDetails do
                xml.tag! :amount, amount(money)
              end
            end
          end
        end
        xml.target!
      end

      # Create the xml document for a full or partial refund  with
      # 
      # Final XML should look like:
      #
      # <Request> 
      #   <Authentication> 
      #     <client>99000001</client> 
      #     <password>*****</password> 
      #   </Authentication> 
      #   <Transaction> 
      #     <CardTxn> 
      #       <Card> 
      #         <pan>633300*********1</pan> 
      #         <expirydate>04/06</expirydate> 
      #         <startdate>01/04</startdate> 
      #       </Card> 
      #       <method>refund</method> 
      #     </CardTxn> 
      #     <TxnDetails> 
      #       <merchantreference>1000001</merchantreference> 
      #       <amount currency="GBP">95.99</amount> 
      #     </TxnDetails> 
      #   </Transaction>
      # </Request>
      def build_refund_request(money, credit_card, options)
        xml = Builder::XmlMarkup.new :indent => 2
        xml.instruct!
        xml.tag! :Request do
          add_authentication(xml)
          xml.tag! :Transaction do
            xml.tag! :CardTxn do
              xml.tag! :method, REFUND_TYPE
              add_credit_card(xml, credit_card, options[:billing_address])
            end
            xml.tag! :TxnDetails do
              xml.tag! :merchantreference, format_reference_number(options[:order_id])
              xml.tag! :amount, amount(money)
            end
          end
        end
        xml.target!
      end


      # Adds the authentication element to the passed builder xml doc
      # 
      # Parameters:
      #   -xml: Builder document that is being built up
      #   
      # Returns:
      #   -none: The results is stored in the passed xml document
      #   
      def add_authentication(xml)
        xml.tag! :Authentication do
          xml.tag! :client, @options[:login]
          xml.tag! :password, @options[:password]
        end
      end

      # Add credit_card detals to the passed XML Builder doc
      # 
      # Parameters:
      #   -xml: Builder document that is being built up
      #   -credit_card: ActiveMerchant::Billing::CreditCard object
      #   -billing_address: Hash containing all of the billing address details
      #   
      # Returns:
      #   -none: The results is stored in the passed xml document
      #   
      def add_credit_card(xml, credit_card, address)
        
        xml.tag! :Card do

          # DataCash calls the CC number 'pan'
          xml.tag! :pan, credit_card.number
          xml.tag! :expirydate, format_date(credit_card.month, credit_card.year)

          # optional values - for Solo etc
          if [ 'switch', 'solo' ].include?(card_brand(credit_card).to_s)
            
            xml.tag! :issuenumber, credit_card.issue_number unless credit_card.issue_number.blank?

            if !credit_card.start_month.blank? && !credit_card.start_year.blank?
              xml.tag! :startdate, format_date(credit_card.start_month, credit_card.start_year)
            end
          end

          xml.tag! :Cv2Avs do
            xml.tag! :cv2, credit_card.verification_value if credit_card.verification_value?
            if address
              xml.tag! :street_address1, address[:address1] unless address[:address1].blank?
              xml.tag! :street_address2, address[:address2] unless address[:address2].blank?
              xml.tag! :street_address3, address[:address3] unless address[:address3].blank?
              xml.tag! :street_address4, address[:address4] unless address[:address4].blank?
              xml.tag! :postcode, address[:zip] unless address[:zip].blank?
            end

            # The ExtendedPolicy defines what to do when the passed data 
            # matches, or not...
            # 
            # All of the following elements MUST be present for the
            # xml to be valid (or can drop the ExtendedPolicy and use
            # a predefined one
            xml.tag! :ExtendedPolicy do
              xml.tag! :cv2_policy, 
              :notprovided =>   POLICY_REJECT,
              :notchecked =>    POLICY_REJECT,
              :matched =>       POLICY_ACCEPT,
              :notmatched =>    POLICY_REJECT,
              :partialmatch =>  POLICY_REJECT
              xml.tag! :postcode_policy,
              :notprovided =>   POLICY_ACCEPT,
              :notchecked =>    POLICY_ACCEPT,
              :matched =>       POLICY_ACCEPT,
              :notmatched =>    POLICY_REJECT,
              :partialmatch =>  POLICY_ACCEPT
              xml.tag! :address_policy, 
              :notprovided =>   POLICY_ACCEPT,
              :notchecked =>    POLICY_ACCEPT,
              :matched =>       POLICY_ACCEPT,
              :notmatched =>    POLICY_REJECT,
              :partialmatch =>  POLICY_ACCEPT
            end
          end
        end
      end

      # Send the passed data to DataCash for processing
      # 
      # Parameters:
      #   -request: The XML data that is to be sent to Datacash
      #   
      # Returns:
      #   - ActiveMerchant::Billing::Response object
      #   
      def commit(request)
        response = parse(ssl_post(test? ? TEST_URL : LIVE_URL, request))      

        Response.new(response[:status] == DATACASH_SUCCESS, response[:reason], response,
          :test => test?,
          :authorization => "#{response[:datacash_reference]};#{response[:authcode]};#{response[:ca_reference]}"
        )
      end

      # Returns a date string in the format Datacash expects
      # 
      # Parameters:
      #   -month: integer, the month
      #   -year: integer, the year
      # 
      # Returns:
      #   -String: date in MM/YY format
      #
      def format_date(month, year)
        "#{format(month,:two_digits)}/#{format(year, :two_digits)}"
      end

      # Parse the datacash response and create a Response object
      #
      # Parameters:
      #   -body: The XML returned from Datacash
      # 
      # Returns:
      #   -a hash with all of the values returned in the Datacash XML response
      # 
      def parse(body)

        response = {}
        xml = REXML::Document.new(body)
        root = REXML::XPath.first(xml, "//Response")

        root.elements.to_a.each do |node|
          parse_element(response, node)
        end

        response
      end     

      # Parse an xml element
      #
      # Parameters:
      #   -response: The hash that the values are being returned in
      #   -node: The node that is currently being read
      # 
      # Returns:
      # -  none (results are stored in the passed hash)
      def parse_element(response, node)
        if node.has_elements?
          node.elements.each{|e| parse_element(response, e) }
        else
          response[node.name.underscore.to_sym] = node.text
        end
      end

      def format_reference_number(number)
        number.to_s.gsub(/[^A-Za-z0-9]/, '').rjust(6, "0").first(30)
      end
    end
  end
end
