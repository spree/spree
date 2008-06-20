module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module PayflowNvCommonAPI
      def self.included(base)
        base.default_currency = 'USD'

        # The certification id requirement has been removed by Payflow
        # This is no longer being sent in the requests to the gateway
        base.class_inheritable_accessor :certification_id

        base.class_inheritable_accessor :partner

        # Set the default partner to PayPal
        base.partner = 'PayPal'

        base.supported_countries = ['US', 'CA', 'SG', 'AU']

        base.class_inheritable_accessor :timeout
        base.timeout = 60

        # Enable safe retry of failed connections
        # Payflow is safe to retry because retried transactions use the same
        # X-VPS-Request-ID header. If a transaction is detected as a duplicate
        # only the original transaction data will be used by Payflow, and the
        # subsequent Responses will have a :duplicate parameter set in the params
        # hash.
        base.retry_safe = true
      end

      TEST_URL = 'https://pilot-payflowpro.verisign.com'
      LIVE_URL = 'https://payflowpro.verisign.com'

      CARD_MAPPING = {
        :visa => 'Visa',
        :master => 'MasterCard',
        :discover => 'Discover',
        :american_express => 'Amex',
        :jcb => 'JCB',
        :diners_club => 'DinersClub',
        :switch => 'Switch',
        :solo => 'Solo'
      }

      TRANSACTIONS = { :purchase      => "S",
                       :authorization => "A",
                       :capture       => "D",
                       :void          => "V",
                       :credit        => "C",
                       :inquiry       => "I",
                       :duplicate     => "N",
                       :recurring     => "R",
                     }

      TENDERS = {
        :credit_card          => 'C',
        :paypal               => 'P',
        :pinless              => 'D',
        :telecheck            => 'K',
        :auto_clearing_house  => 'A',
      }

      CVV_CODE = {
        'Match' => 'M',
        'No Match' => 'N',
        'Service Not Available' => 'U',
        'Service not Requested' => 'P'
      }

      def initialize(options = {})
        requires!(options, :login, :password)
        @options = {
          :certification_id => self.class.certification_id,
          :partner => self.class.partner
        }.update(options)
        super
      end

      def test?
        @options[:test] || super
      end

      def capture(money, authorization, options = {})
        post = { :origid => authorization }

        add_amount(post, money, options)
        commit(:capture, post)
      end

      def void(authorization, options = {})
        post = { :origid => authorization }
        commit(:void, post)
      end


      def test?
        @options[:test] || Base.gateway_mode == :test
      end


      private
      def add_pair(post, key, value, options = {})
        post[key] = value if not value.blank? || options[:allow_blank]
      end

      def add_reference(post, reference, options)
        post[:tender] = TENDERS[:credit_card]
        add_pair(post, :origid, reference)
      end

      def add_amount(post, money, options)
        add_pair(post, :amt, amount(money), :allow_blank => false)
        add_pair(post, :currency, currency(money))
        add_pair(post, :taxamt, amount(options[:tax]))
      end

      def add_invoice(post, options)
        add_pair(post, :invnum, options[:order_id])
        add_pair(post, :custref, options[:order_id])
        add_pair(post, :custcode, options[:order_id])
        add_pair(post, :desc, options[:description])
      end

      def add_customer_data(post, options)
        add_pair(post, :custip, options[:ip])
        add_pair(post, :email, options[:email])
      end

      def add_addresses(post, options)
        billing_address = options[:billing_address] || options[:address]
        shipping_address = options[:shipping_address] || billing_address

        add_billing_address(post, billing_address)
        add_shipping_address(post, shipping_address)
      end


      def add_shipping_address(post, address)
        return if address.nil?

        add_pair(post, :shiptofirstname, address[:name])
        add_pair(post, :shiptostreet, address[:address1])
        add_pair(post, :shiptocity, address[:city])
        add_pair(post, :shiptostate, address[:state])
        add_pair(post, :shiptozip, address[:zip])
        add_pair(post, :shiptocountry, address[:country])
      end

      def add_billing_address(post, address)
        return if address.nil?

        add_pair(post, :companyname, address[:company])
        add_pair(post, :street, address[:address1])
        add_pair(post, :city, address[:city])
        add_pair(post, :state, address[:state])
        add_pair(post, :zip, address[:zip])
        add_pair(post, :billtocountry, address[:country])
        add_pair(post, :phonenum, address[:phone])
      end

      def build_reference_request(money, authorization, options)
        post = {}
        add_reference(post, authorization, options)
        post
      end

      def post_headers(content_length)
        {
          "Content-Type" => "text/namevalue",
          "Content-Length" => content_length.to_s,
         "X-VPS-Timeout" => timeout.to_s,
         "X-VPS-VIT-Integration-Product" => "ActiveMerchant",
         "X-VPS-VIT-Runtime-Version" => RUBY_VERSION,
         "X-VPS-Request-ID" => generate_unique_id
         }
       end

       def post_data(action, post)
        post[:trxtype]    = TRANSACTIONS[action]
        post[:partner]    = @options[:partner]
        post[:vendor]     = @options[:login]
        post[:user]       = @options[:login]
        post[:pwd]        = @options[:password]
        post[:verbosity]  = 'MEDIUM'

        request = post.collect do |key, value|
          sanitized_data = value.to_s.gsub('"', '')
          "#{key.to_s.upcase}[#{sanitized_data.size}]=#{sanitized_data}"
        end.join("&")

        request
      end

      def commit(action, post)
       request = post_data(action, post)
       headers = post_headers(request.size)
      
        url = test? ? TEST_URL : LIVE_URL
        data = ssl_post(url, request, headers)
        
        response = parse(data)
            
        success = response[:result] == "0"
        message = response[:respmsg]
      
        build_response(success, message, response,
          :authorization => response[:pnref] || response[:rpref],
          :cvv_result => response[:cvv2_match],
          :avs_result => {
           :street_match => response[:avsaddr],
           :postal_match => response[:avszip],
           :code => response[:procavs],
          },
         :test => test?
       )
      end
      
      def parse(data)
        fields = {}
        for line in data.split('&')
          key, value = *line.scan( %r{^(\w+)\=(.*)$} ).flatten
          fields[key.underscore.to_sym] = value
        end
        fields
      end
    end
  end
end
