module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class TransFirstGateway < Gateway
      URL = 'https://webservices.primerchants.com/creditcard.asmx/CCSale'

      self.supported_countries = ['US']
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      self.homepage_url = 'http://www.transfirst.com/'
      self.display_name = 'TransFirst'
      
      UNUSED_FIELDS = %w(ECIValue UserId CAVVData TrackData POSInd EComInd MerchZIP MerchCustPNum MCC InstallmentNum InstallmentOf POSEntryMode POSConditionCode AuthCharInd CardCertData)

      DECLINED = 'The transaction was declined'

      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options
        super
      end  
  
      def purchase(money, credit_card, options = {})
        post = {}
        
        add_amount(post, money)
        add_invoice(post, options)
        add_credit_card(post, credit_card)        
        add_address(post, options)   
             
        commit(post)
      end                       
  
      private                       
      def add_amount(post, money)
        add_pair(post, :Amount, amount(money), :required => true)
      end
      
      def add_address(post, options)
        address = options[:billing_address] || options[:address]
        
        if address
          add_pair(post, :Address, address[:address1])
          add_pair(post, :ZipCode, address[:zip])
        end
      end

      def add_invoice(post, options)
        add_pair(post, :RefID, options[:order_id], :required => true)
        add_pair(post, :PONumber, options[:invoice], :required => true)
        add_pair(post, :SaleTaxAmount, amount(options[:tax] || 0))
        add_pair(post, :PaymentDesc, options[:description], :required => true)
        add_pair(post, :TaxIndicator, 0)
      end
      
      def add_credit_card(post, credit_card)
        add_pair(post, :CardHolderName, credit_card.name, :required => true)
        add_pair(post, :CardNumber, credit_card.number, :required => true)
        
        add_pair(post, :Expiration, expdate(credit_card), :required => true)
        add_pair(post, :CVV2, credit_card.verification_value)
      end
      
      def add_unused_fields(post)
        UNUSED_FIELDS.each do |f|
          post[f] = ""
        end
      end
      
      def expdate(credit_card)
        year  = format(credit_card.year, :two_digits)
        month = format(credit_card.month, :two_digits)

        "#{month}#{year}"
      end
      
      def parse(data)
        response = {}
        
        xml = REXML::Document.new(data)
        root = REXML::XPath.first(xml, "//CCSaleDebitResponse")
        
        if root.nil?
          response[:message] = data.to_s.strip
        else
          root.elements.to_a.each do |node|
            response[node.name.underscore.to_sym] = node.text
          end
        end
      
        response
      end
      
      def commit(params) 
        response = parse( ssl_post(URL, post_data(params)) )

        Response.new(response[:status] == "Authorized", message_from(response), response, 
          :test => test?, 
          :authorization => response[:trans_id],
          :avs_result => { :code => response[:avs_code] },
          :cvv_result => response[:cvv2_code]
        )
      end
      
      def message_from(response)
        case response[:message]
        when 'Call Voice Center'
          DECLINED
        else
          response[:message]
        end
      end
      
      def post_data(params = {})
        add_unused_fields(params)
        params[:MerchantID] = @options[:login]
        params[:RegKey] = @options[:password]
        
        request = params.collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
        request
      end
      
      def add_pair(post, key, value, options = {})
        post[key] = value if !value.blank? || options[:required]
      end
    end
  end
end

