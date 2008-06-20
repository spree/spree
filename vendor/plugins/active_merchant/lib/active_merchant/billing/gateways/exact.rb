module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class ExactGateway < Gateway
      URL = 'https://secure2.e-xact.com/vplug-in/transaction/rpc-enc/service.asmx'
      
      API_VERSION = "8.5"
      
      TEST_LOGINS = [ {:login => "A00049-01", :password => "test1"},
                      {:login => "A00427-01", :password => "testus"} ]
      
      TRANSACTIONS = { :sale          => "00",
                       :authorization => "01",
                       :capture       => "32",
                       :credit        => "34" }
      

      ENVELOPE_NAMESPACES = { 'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema',
                              'xmlns:env' => 'http://schemas.xmlsoap.org/soap/envelope/',
                              'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance'
                            }
                            
      SEND_AND_COMMIT_ATTRIBUTES = { 'xmlns:n1' => "http://secure2.e-xact.com/vplug-in/transaction/rpc-enc/Request",
                                     'env:encodingStyle' => 'http://schemas.xmlsoap.org/soap/encoding/'
                                   }
                                   
      SEND_AND_COMMIT_SOURCE_ATTRIBUTES = { 'xmlns:n2' => 'http://secure2.e-xact.com/vplug-in/transaction/rpc-enc/encodedTypes',
                                            'xsi:type' => 'n2:Transaction'
                                          }
      
      POST_HEADERS = { 'soapAction' => "http://secure2.e-xact.com/vplug-in/transaction/rpc-enc/SendAndCommit",
                       'Content-Type' => 'text/xml' 
                     }
                     
      SUCCESS = "true"
      
      SENSITIVE_FIELDS = [ :verification_str2, :expiry_date, :card_number ]
      
      self.supported_cardtypes = [:visa, :master, :american_express, :jcb, :discover]
      self.supported_countries = ['CA', 'US']
      self.homepage_url = 'http://www.e-xact.com'
      self.display_name = 'E-xact'
  
      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options
        
        if TEST_LOGINS.include?( { :login => options[:login], :password => options[:password] } )
          @test_mode = true
        end
      
        super
      end
      
      def test?
        @test_mode || Base.gateway_mode == :test
      end
      
      def authorize(money, credit_card, options = {})
        commit(:authorization, build_sale_or_authorization_request(money, credit_card, options))
      end
      
      def purchase(money, credit_card, options = {})
        commit(:sale, build_sale_or_authorization_request(money, credit_card, options))
      end
    
      def capture(money, authorization, options = {})
        commit(:capture, build_capture_or_credit_request(money, authorization, options))
      end

      def credit(money, authorization, options = {})
        commit(:credit, build_capture_or_credit_request(money, authorization, options))
      end
         
      private                       
      def build_request(action, body)
        xml = Builder::XmlMarkup.new
        
        xml.instruct!
        xml.tag! 'env:Envelope', ENVELOPE_NAMESPACES do
          xml.tag! 'env:Body' do
            xml.tag! 'n1:SendAndCommit', SEND_AND_COMMIT_ATTRIBUTES do
              xml.tag! 'SendAndCommitSource', SEND_AND_COMMIT_SOURCE_ATTRIBUTES do
                add_credentials(xml)
                add_transaction_type(xml, action)
                xml << body
              end
            end
          end
        end
        xml.target!
      end
                
      def build_sale_or_authorization_request(money, credit_card, options)
        xml = Builder::XmlMarkup.new
 
        add_amount(xml, money)
        add_credit_card(xml, credit_card)
        add_customer_data(xml, options)
        add_invoice(xml, options)
        
        xml.target!        
      end
      
      def build_capture_or_credit_request(money, identification, options)
        xml = Builder::XmlMarkup.new
  
        add_identification(xml, identification)
        add_amount(xml, money)
        add_customer_data(xml, options)
    
        xml.target!
      end
      
      def add_credentials(xml)
        xml.tag! 'ExactID', @options[:login]
        xml.tag! 'Password', @options[:password]
      end
      
      def add_transaction_type(xml, action)
        xml.tag! 'Transaction_Type', TRANSACTIONS[action]
      end
      
      def add_identification(xml, identification)
        authorization_num, transaction_tag = identification.split(';')
 
        xml.tag! 'Authorization_Num', authorization_num
        xml.tag! 'Transaction_Tag', transaction_tag
      end
      
      def add_amount(xml, money)
        xml.tag! 'DollarAmount', amount(money)
      end
      
      def add_credit_card(xml, credit_card)
        xml.tag! 'Card_Number', credit_card.number
        xml.tag! 'Expiry_Date', expdate(credit_card)
        xml.tag! 'CardHoldersName', credit_card.name
        
        if credit_card.verification_value?
          xml.tag! 'CVD_Presence_Ind', '1'
          xml.tag! 'VerificationStr2', credit_card.verification_value
        end
      end
      
      def add_customer_data(xml, options)
        xml.tag! 'Customer_Ref', options[:customer]
        xml.tag! 'Client_IP', options[:ip]
        xml.tag! 'Client_Email', options[:email]
      end

      def add_address(xml, options)
        if address = options[:billing_address] || options[:address]
          xml.tag! 'ZipCode', address[:zip]       
        end    
      end

      def add_invoice(xml, options)
        xml.tag! 'Reference_No', options[:order_id]
        xml.tag! 'Reference_3',  options[:description]
      end
      
      def expdate(credit_card)
        "#{format(credit_card.month, :two_digits)}#{format(credit_card.year, :two_digits)}"
      end
      
      def commit(action, request)
         response = parse(ssl_post(URL, build_request(action, request), POST_HEADERS))
      
         Response.new(successful?(response), message_from(response), response,
           :test => test?,
           :authorization => authorization_from(response),
           :avs_result => { :code => response[:avs] },
           :cvv_result => response[:cvv2]
         )
      end
      
      def successful?(response)
        response[:transaction_approved] == SUCCESS
      end
      
      def authorization_from(response)
        if response[:authorization_num] && response[:transaction_tag]
           "#{response[:authorization_num]};#{response[:transaction_tag]}"        
        else
           ''
        end
      end
      
      def message_from(response)
        if response[:faultcode] && response[:faultstring]
          response[:faultstring]
        elsif response[:error_number] != '0'
          response[:error_description]
        else
          result = response[:exact_message] || ''
          result << " - #{response[:bank_message]}" unless response[:bank_message].blank?
          result
        end
      end
      
      def parse(xml)
        response = {}
        xml = REXML::Document.new(xml)
        
        if root = REXML::XPath.first(xml, "//types:TransactionResult")
          parse_elements(response, root)
        elsif root = REXML::XPath.first(xml, "//soap:Fault")
          parse_elements(response, root)
        end

        response.delete_if{ |k,v| SENSITIVE_FIELDS.include?(k) }
      end

      def parse_elements(response, root)
        root.elements.to_a.each do |node|
          response[node.name.gsub(/EXact/, 'Exact').underscore.to_sym] = (node.text || '').strip
        end
      end
    end
  end
end

