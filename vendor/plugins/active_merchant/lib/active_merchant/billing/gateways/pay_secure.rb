module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PaySecureGateway < Gateway
      URL = 'https://clearance.commsecure.com.au/cgi-bin/PSDirect'
      
      self.money_format = :cents

      # Currently Authorization and Capture is not implemented because
      # capturing requires the original credit card information
      TRANSACTIONS = {
        :purchase       => 'PURCHASE',
        :authorization  => 'AUTHORISE',
        :capture        => 'ADVICE', 
        :credit         => 'REFUND'
      }
      
      SUCCESS = 'Accepted'
      SUCCESS_MESSAGE = 'The transaction was approved'
      
      self.supported_countries = ['AU']
      self.homepage_url = 'http://www.commsecure.com.au/paysecure.shtml'
      self.display_name = 'PaySecure'
      self.supported_cardtypes = [:visa, :master, :american_express, :diners_club]

      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options
        super
      end  

      def purchase(money, credit_card, options = {})
        requires!(options, :order_id)
        
        post = {}
        add_amount(post, money)
        add_invoice(post, options)
        add_credit_card(post, credit_card)        
             
        commit(:purchase, money, post)
      end                       
         
      private
      # Used for capturing, which is currently not supported.
      def add_reference(post, identification)
        auth, trans_id = identification.split(";")
        post[:authnum]    = auth
        post[:transid] = trans_id
      end
      
      def add_amount(post, money)
        post[:amount] = amount(money)
      end
      
      def add_invoice(post, options)
        post[:merchant_transid] = options[:order_id].to_s.slice(0,21)
        post[:memnum]           = options[:invoice]
        post[:custnum]          = options[:customer]
        post[:clientdata]       = options[:description]
      end
      
      def add_credit_card(post, credit_card)      
        post[:cardnum]  = credit_card.number
        post[:cardname] = credit_card.name
        post[:expiry]   = expdate(credit_card)
        post[:cvv2]     = credit_card.verification_value
      end
      
      def expdate(credit_card)
        year  = sprintf("%.4i", credit_card.year)
        month = sprintf("%.2i", credit_card.month)

        "#{month}#{year[-2..-1]}"
      end
       
      def commit(action, money, parameters)
        response = parse( ssl_post(URL, post_data(action, parameters)) )
        
        Response.new(successful?(response), message_from(response), response, 
          :test => test_response?(response), 
          :authorization => authorization_from(response)
        )
        
      end
      
      def successful?(response)
        response[:status] == SUCCESS
      end
      
      def authorization_from(response)
        [ response[:authnum], response[:transid] ].compact.join(";")
      end
      
      def test_response?(response)
        !!(response[:transid] =~ /SimProxy/)
      end
      
      def message_from(response)
        successful?(response) ? SUCCESS_MESSAGE : response[:errorstring]
      end
      
      def parse(body)
        response = {}
        body.collect do |l| 
          key, value = l.split(":", 2)
          response[key.to_s.downcase.to_sym] = value.strip
        end
        response
      end 
      
      def post_data(action, parameters = {})
        parameters[:request_type]     = TRANSACTIONS[action]
        parameters[:merchant_id]      = @options[:login]
        parameters[:password]         = @options[:password]
        
        parameters.reject{|k,v| v.blank?}.collect { |key, value| "#{key.to_s.upcase}=#{CGI.escape(value.to_s)}" }.join("&")
      end
    end
  end
end

