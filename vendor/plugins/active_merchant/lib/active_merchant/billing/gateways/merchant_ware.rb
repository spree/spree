module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class MerchantWareGateway < Gateway
      URL = 'https://ps1.merchantware.net/MerchantWARE/ws/RetailTransaction/TXRetail.asmx'
      
      self.supported_countries = ['US']
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      self.homepage_url = 'http://merchantwarehouse.com/merchantware'
      self.display_name = 'MerchantWARE'
      
      ENV_NAMESPACES = { "xmlns:xsi"  => "http://www.w3.org/2001/XMLSchema-instance",
                         "xmlns:xsd"  => "http://www.w3.org/2001/XMLSchema",
                         "xmlns:env" => "http://schemas.xmlsoap.org/soap/envelope/"
                       }
      TX_NAMESPACE = "http://merchantwarehouse.com/MerchantWARE/Client/TransactionRetail"
      
      ACTIONS = {
        :purchase  => "IssueKeyedSale",
        :authorize => "IssueKeyedPreAuth",
        :capture   => "IssuePostAuth",
        :void      => "IssueVoid",
        :credit    => "IssueKeyedRefund",
        :reference_credit => "IssueRefundByReference"
      }
      
      # Creates a new MerchantWareGateway
      # 
      # The gateway requires that a valid login, password, and name be passed
      # in the +options+ hash.
      # 
      # ==== Options
      #
      # * <tt>:login</tt> - The MerchantWARE SiteID.
      # * <tt>:password</tt> - The MerchantWARE Key.
      # * <tt>:name</tt> - The MerchantWARE Name.
      def initialize(options = {})
        requires!(options, :login, :password, :name)
        @options = options
        super
      end

      # Authorize a credit card for a given amount.
      # 
      # ==== Parameters
      # * <tt>money</tt> - The amount to be authorized.  Either an Integer value in cents or a Money object.
      # * <tt>credit_card</tt> - The CreditCard details for the transaction.
      # * <tt>options</tt>
      #   * <tt>:order_id</tt> - A unique reference for this order (required).
      #   * <tt>:billing_address</tt> - The billing address for the cardholder.      
      def authorize(money, credit_card, options = {})
        request = build_purchase_request(:authorize, money, credit_card, options)
        commit(:authorize, request)
      end
      
      # Authorize and immediately capture funds from a credit card.
      # 
      # ==== Parameters
      # * <tt>money</tt> - The amount to be authorized.  Either an Integer value in cents or a Money object.
      # * <tt>credit_card</tt> - The CreditCard details for the transaction.
      # * <tt>options</tt>
      #   * <tt>:order_id</tt> - A unique reference for this order (required).
      #   * <tt>:billing_address</tt> - The billing address for the cardholder.
      def purchase(money, credit_card, options = {})
        request = build_purchase_request(:purchase, money, credit_card, options)
        commit(:purchase, request)
      end                       

      # Capture authorized funds from a credit card.
      # 
      # ==== Parameters
      # * <tt>money</tt> - The amount to be captured.  Either an Integer value in cents or a Money object.
      # * <tt>authorization</tt> - The authorization string returned from the initial authorization.
      def capture(money, authorization, options = {})
        request = build_capture_request(:capture, money, authorization, options)
        commit(:capture, request)
      end

      # Void a transaction.
      # 
      # ==== Parameters
      # * <tt>authorization</tt> - The authorization string returned from the initial authorization or purchase.
      def void(authorization, options = {})
        reference, options[:order_id] = split_reference(authorization)
        
        request = soap_request(:void) do |xml|
          add_reference(xml, reference)
        end
        commit(:void, request)
      end
      
      # Refund an amount back a cardholder
      # 
      # ==== Parameters
      #
      # * <tt>money</tt> - The amount to be refunded. Either an Integer value in cents or a Money object.
      # * <tt>identification</tt> - The credit card you want to refund or the authorization for the existing transaction you are refunding.
      # * <tt>options</tt>
      #   * <tt>:order_id</tt> - A unique reference for this order (required when performing a non-referenced credit)
      def credit(money, identification, options = {})
        if identification.is_a?(String)          
          perform_reference_credit(money, identification, options)
        else
          perform_credit(money, identification, options)
        end
      end
    
      private
      
      def soap_request(action)
        xml = Builder::XmlMarkup.new :indent => 2
        xml.instruct!
        xml.tag! "env:Envelope", ENV_NAMESPACES do
          xml.tag! "env:Body" do
            xml.tag! ACTIONS[action], "xmlns" => TX_NAMESPACE do
              add_credentials(xml)
              yield xml
            end
          end
        end
        xml.target!
      end
      
      def build_purchase_request(action, money, credit_card, options)
        requires!(options, :order_id)
        
        request = soap_request(action) do |xml|
          add_invoice(xml, options)
          add_amount(xml, money)
          add_credit_card(xml, credit_card)
          add_address(xml, options)
        end
      end
      
      def build_capture_request(action, money, identification, options)
        reference, options[:order_id] = split_reference(identification)
        
        request = soap_request(action) do |xml|
          add_reference(xml, reference)
          add_invoice(xml, options)
          add_amount(xml, money)
        end
      end
      
      def perform_reference_credit(money, identification, options)
        reference, options[:order_id] = split_reference(identification)

        request = soap_request(:reference_credit) do |xml|
          add_reference(xml, reference)
          add_invoice(xml, options)
          add_amount(xml, money, "strOverrideAmount")
        end
        
        commit(:reference_credit, request)
      end
      
      def perform_credit(money, credit_card, options)
        requires!(options, :order_id)
        
        request = soap_request(:credit) do |xml|
          add_invoice(xml, options)
          add_amount(xml, money)
          add_credit_card(xml, credit_card)
        end
        
        commit(:credit, request)
      end

      def add_credentials(xml)
        xml.tag! "strSiteId", @options[:login]
        xml.tag! "strKey", @options[:password]
        xml.tag! "strName", @options[:name]
      end
      
      def expdate(credit_card)
        year  = sprintf("%.4i", credit_card.year)
        month = sprintf("%.2i", credit_card.month)

        "#{month}#{year[-2..-1]}"
      end
      
      def add_invoice(xml, options)
        xml.tag! "strOrderNumber", options[:order_id].to_s.slice(0, 25)
      end
      
      def add_amount(xml, money, tag = "strAmount")
        xml.tag! tag, amount(money)
      end

      def add_reference(xml, reference)
        xml.tag! "strReferenceCode", reference
      end
      
      def add_address(xml, options)
        if address = options[:billing_address] || options[:address]
          xml.tag! "strAVSStreetAddress", address[:address1]
          xml.tag! "strAVSZipCode", address[:zip]
        end
      end
      
      def add_credit_card(xml, credit_card)
        xml.tag! "strPAN", credit_card.number
        xml.tag! "strExpDate", expdate(credit_card)
        xml.tag! "strCardHolder", credit_card.name
        xml.tag! "strCVCode", credit_card.verification_value if credit_card.verification_value?
      end
      
      def split_reference(reference)
        reference.to_s.split(";")
      end
      
      def parse(action, data)
        response = {}
        xml = REXML::Document.new(data)
      
        root = REXML::XPath.first(xml, "//#{ACTIONS[action]}Response/#{ACTIONS[action]}Result")

        root.elements.each do |element|
          response[element.name] = element.text
        end
        
        status, code, message = response["ApprovalStatus"].split(";")
        response[:status] = status
        
        if response[:success] = status == "APPROVED"          
          response[:message] = status
        else
          response[:message] = message
          response[:failure_code] = code
        end

        response        
      end
      
      def parse_error(http_response)
        response = {}
        response[:http_code] = http_response.code
        response[:http_message] = http_response.message
        response[:success] = false

        document = REXML::Document.new(http_response.body)

        node     = REXML::XPath.first(document, "//soap:Fault")
        
        node.elements.each do |element|
          response[element.name] = element.text
        end
        
        response[:message] = response["faultstring"].to_s.gsub("\n", " ")
        response
      rescue REXML::ParseException => e
        response[:http_body]        = http_response.body
        response[:message]          = "Failed to parse the failed response"
        response
      end
            
      def commit(action, request)
        begin
          data = ssl_post(URL, request, 
                   "Content-Type" => 'text/xml; charset=utf-8',
                   "SOAPAction"   => "http://merchantwarehouse.com/MerchantWARE/Client/TransactionRetail/#{ACTIONS[action]}"
                 )
          response = parse(action, data)
        rescue ActiveMerchant::ResponseError => e
          response = parse_error(e.response)
        end
        
        Response.new(response[:success], response[:message], response, 
          :test => test?, 
          :authorization => authorization_from(response),
          :avs_result => { :code => response["AVSResponse"] },
          :cvv_result => response["CVResponse"]
        )
      end
      
      def authorization_from(response)
        if response[:success]
          [ response["ReferenceID"], response["OrderNumber"] ].join(";")
        end
      end
    end
  end
end

