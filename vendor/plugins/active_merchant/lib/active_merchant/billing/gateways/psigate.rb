#  This class implements the Psigate gateway for the ActiveMerchant module.
#  Psigate = http://www.psigate.com/ The class  is currently set up to use
#  the psigate test server while rails is in testing or developement mode.
#  The real server will be used while in production mode.
#  
#  Modifications by Sean O'Hara ( sohara at sohara dot com )
#  
#  Usage for a PreAuth (authorize) is as follows:
#  
#  twenty = 2000
#  gateway = PsigateGateway.new(
#    :login => 'teststore',
#    :password => 'psigate1234'
#  )
#  
#  creditcard = CreditCard.new(
#    :number => '4242424242424242',
#    :month => 8,
#    :year => 2006,
#    :first_name => 'Longbob',
#    :last_name => 'Longsen'
#  )
#  response = @gateway.authorize(twenty, creditcard,
#     :order_id =>  1234,
#     :billing_address => {
#  	    :address1 => '123 fairweather Lane',
#  	    :address2 => 'Apt B',
#  	    :city => 'New York',
#  	    :state => 'NY',
#  	    :country => 'U.S.A.',
#  	    :zip => '10010'
#    },
#    :email => 'jack@yahoo.com'
#  )

require 'rexml/document'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:

    class PsigateGateway < Gateway
      TEST_URL  = 'https://dev.psigate.com:7989/Messenger/XMLMessenger'
      LIVE_URL  = 'https://secure.psigate.com:7934/Messenger/XMLMessenger'
      
      self.supported_cardtypes = [:visa, :master, :american_express]
      self.supported_countries = ['CA']
      self.homepage_url = 'http://www.psigate.com/'
      self.display_name = 'Psigate'
   
      SUCCESS_MESSAGE = 'Success'
      FAILURE_MESSAGE = 'The transaction was declined'
      
      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options                          
        super      
      end      
    
      # Psigate PreAuth
      def authorize(money, creditcard, options = {})
        requires!(options, :order_id)                                                          
        options.update({ :CardAction => "1" })
        commit(money, creditcard, options)      
      end
      
      # Psigate Sale
      def purchase(money, creditcard, options = {})
        requires!(options, :order_id)                                                          
        options.update({ :CardAction => "0" })
        commit(money, creditcard, options)     
      end
      
      # Psigate PostAuth
      def capture(money, authorization, options = {})
        options.update({ :CardAction => "2", :order_id => authorization })
        commit(money, nil, options)
      end
      

      # Psigate Credit
      def credit(money, authorization, options = {})
        options.update({ :CardAction => "3", :order_id => authorization })
        commit(money, nil, options)
      end

      private                       
    
      def commit(money, creditcard, options = {}) 
        response = parse(ssl_post(test? ? TEST_URL : LIVE_URL, post_data(money, creditcard, options)))

        Response.new(successful?(response), message_from(response), response, 
          :test => test?, 
          :authorization => response[:orderid],
          :avs_result => { :code => response[:avsresult] },
          :cvv_result => response[:cardidresult]
        )
      end
      
      def successful?(response)
        response[:approved] == "APPROVED"
      end
                                               
      def parse(xml)
        response = {:message => "Global Error Receipt", :complete => false}

        xml = REXML::Document.new(xml)          
        xml.elements.each('//Result/*') do |node|

          response[node.name.downcase.to_sym] = normalize(node.text)

        end unless xml.root.nil?

        response
      end     

      def post_data(money, creditcard, options)
        xml = REXML::Document.new
        xml << REXML::XMLDecl.new
        root  = xml.add_element("Order")
        
        for key, value in parameters(money, creditcard, options)
          root.add_element(key.to_s).text = value if value
        end    

        xml.to_s
      end
      
      # Set up the parameters hash just once so we don't have to do it
      # for every action. 
      def parameters(money, creditcard, options = {})  
        params = {
          # General order paramters
          :StoreID => @options[:login],
          :Passphrase => @options[:password],
          :TestResult => options[:test_result],
          :OrderID => options[:order_id],
          :UserID => options[:user_id],
          :Phone => options[:phone],
          :Fax => options[:fax],
          :Email => options[:email],
          
          # Credit Card paramaters
          :PaymentType => "CC",
          :CardAction => options[:CardAction],
          
          # Financial paramters
          :CustomerIP => options[:ip],
          :SubTotal => amount(money),
          :Tax1 => options[:tax1],
          :Tax2 => options[:tax2],
          :ShippingTotal => options[:shipping_total],
        }

        if creditcard
          exp_month = sprintf("%.2i", creditcard.month) unless creditcard.month.blank?
          exp_year = creditcard.year.to_s[2,2] unless creditcard.year.blank?
          card_id_code = creditcard.verification_value.blank? ? nil : "1"

          params.update( 
            :CardNumber => creditcard.number,
            :CardExpMonth => exp_month,
            :CardExpYear => exp_year,
            :CardIDCode => card_id_code,
            :CardIDNumber => creditcard.verification_value
          )
        end
        
        if address = options[:billing_address] || options[:address]           
          params[:Bname] = address[:name] || creditcard.name 
          params[:Baddress1]    = address[:address1] unless address[:address1].blank?
          params[:Baddress2]    = address[:address2] unless address[:address2].blank?
          params[:Bcity]        = address[:city]     unless address[:city].blank?
          params[:Bprovince]    = address[:state]    unless address[:state].blank?
          params[:Bpostalcode]  = address[:zip]      unless address[:zip].blank?
          params[:Bcountry]     = address[:country]  unless address[:country].blank?
          params[:Bcompany]     = address[:company]  unless address[:company].blank?
        end
        
        if address = options[:shipping_address]
          params[:Sname]        = address[:name] || creditcard.name 
          params[:Saddress1]    = address[:address1] unless address[:address1].blank?
          params[:Saddress2]    = address[:address2] unless address[:address2].blank?
          params[:Scity]        = address[:city]     unless address[:city].blank?
          params[:Sprovince]    = address[:state]    unless address[:state].blank?
          params[:Spostalcode]  = address[:zip]      unless address[:zip].blank?
          params[:Scountry]     = address[:country]  unless address[:country].blank?
          params[:Scompany]     = address[:company]  unless address[:company].blank?
        end
       	 	
        return params
      end
      
      def message_from(response)
        if response[:approved] == "APPROVED"
          return SUCCESS_MESSAGE
        else
          return FAILURE_MESSAGE if response[:errmsg].blank?
          return response[:errmsg].gsub(/[^\w]/, ' ').split.join(" ").capitalize
        end
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
