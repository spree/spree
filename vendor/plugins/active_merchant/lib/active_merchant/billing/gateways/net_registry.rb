module ActiveMerchant
  module Billing
    # Gateway for netregistry.com.au.
    #
    # Note that NetRegistry itself uses gateway service providers.  At the
    # time of this writing, there are at least two (Quest and Ingenico).
    # This module has only been tested with Quest.
    #
    # Also note that NetRegistry does not offer a test mode, nor does it
    # have support for the authorize/capture/void functionality by default
    # (you may arrange for this as described in "Programming for
    # NetRegistry's E-commerce Gateway." [http://rubyurl.com/hNG]), and no
    # #void functionality is documented.  As a result, the #authorize and
    # #capture have not yet been tested through a live gateway, and #void
    # will raise an error.
    #
    # If you have this functionality enabled, please consider contributing
    # to ActiveMerchant by writing tests/code for these methods, and
    # submitting a patch.
    #
    # In addition to the standard ActiveMerchant functionality, the
    # response will contain a 'receipt' parameter
    # (response.params['receipt']) if a receipt was issued by the gateway.
    class NetRegistryGateway < Gateway
      URL = 'https://4tknox.au.com/cgi-bin/themerchant.au.com/ecom/external2.pl'
      
      FILTERED_PARAMS = [ 'card_no', 'card_expiry', 'receipt_array' ]
      
      self.supported_countries = ['AU']
      
      # Note that support for Diners, Amex, and JCB require extra
      # steps in setting up your account, as detailed in
      # "Programming for NetRegistry's E-commerce Gateway."
      # [http://rubyurl.com/hNG]
      self.supported_cardtypes = [:visa, :master, :diners_club, :american_express, :jcb]
      self.display_name = 'NetRegistry'
      self.homepage_url = 'http://www.netregistry.com.au'
      
      TRANSACTIONS = {
        :authorization => 'preauth',
        :purchase => 'purchase',
        :capture => 'completion',
        :status => 'status',
        :credit => 'refund'
      }
      
      # Create a new NetRegistry gateway.
      #
      # Options :login and :password must be given.
      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options
        super
      end

      # Note that #authorize and #capture only work if your account
      # vendor is St George, and if your account has been setup as
      # described in "Programming for NetRegistry's E-commerce
      # Gateway." [http://rubyurl.com/hNG]
      def authorize(money, credit_card, options = {})
        params = {
          'AMOUNT'  => amount(money),
          'CCNUM'   => credit_card.number,
          'CCEXP'   => expiry(credit_card)
        }
        add_request_details(params, options)
        commit(:authorization, params)
      end

      # Note that #authorize and #capture only work if your account
      # vendor is St George, and if your account has been setup as
      # described in "Programming for NetRegistry's E-commerce
      # Gateway." [http://rubyurl.com/hNG]
      def capture(money, authorization, options = {})
        requires!(options, :credit_card)
        credit_card = options[:credit_card]

        params = {
          'PREAUTHNUM' => authorization,
          'AMOUNT'     => amount(money),
          'CCNUM'      => credit_card.number,
          'CCEXP'      => expiry(credit_card)
        }
        add_request_details(params, options)
        commit(:capture, params)
      end

      def purchase(money, credit_card, options = {})
        params = {
          'AMOUNT'  => amount(money),
          'CCNUM'   => credit_card.number,
          'CCEXP'   => expiry(credit_card)
        }
        add_request_details(params, options)
        commit(:purchase, params)
      end

      def credit(money, identification, options = {})
        params = {
          'AMOUNT'  => amount(money),
          'TXNREF'  => identification
        }
        add_request_details(params, options)
        commit(:credit, params)
      end
      
      # Specific to NetRegistry.
      #
      # Run a 'status' command.  This lets you view the status of a
      # completed transaction.
      #
      def status(identification)
        params = {
          'TXNREF'  => identification
        }
        
        commit(:status, params)
      end

      private
      def add_request_details(params, options)
        params['COMMENT'] = options[:description] unless options[:description].blank?
      end
      
      # Return the expiry for the given creditcard in the required
      # format for a command.
      def expiry(credit_card)
        month = format(credit_card.month, :two_digits)
        year  = format(credit_card.year , :two_digits)
        "#{month}/#{year}"
      end

      # Post the a request with the given parameters and return the
      # response object.
      #
      # Login and password are added automatically, and the comment is
      # omitted if nil.
      def commit(action, params)
        # get gateway response
        response = parse( ssl_post(URL, post_data(action, params)) )
        
        Response.new(response['status'] == 'approved', message_from(response), response,          
          :authorization => authorization_from(response, action)
        )
      end
      
      def post_data(action, params)
        params['COMMAND'] = TRANSACTIONS[action]
        params['LOGIN'] = "#{@options[:login]}/#{@options[:password]}"
        URI.encode(params.map{|k,v| "#{k}=#{v}"}.join('&'))
      end
      
      def parse(response)
        params = {}
        
        lines = response.split("\n")
        
        # Just incase there is no real response returned
        params['status'] = lines[0]
        params['response_text'] = lines[1]
        
        started = false
        lines.each do |line|          
          if started
            key, val = line.chomp.split(/=/, 2)
            params[key] = val unless FILTERED_PARAMS.include?(key)
          end
          
          started = line.chomp =~ /^\.$/ unless started
        end
        
        params
      end
      
      def message_from(response)
        response['response_text']
      end
      
      def authorization_from(response, command)
        case command
        when :purchase
          response['txn_ref']
        when :authorization
          response['transaction_no']
        end
      end
    end
  end
end
