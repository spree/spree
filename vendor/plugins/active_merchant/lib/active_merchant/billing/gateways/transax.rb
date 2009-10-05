require File.join(File.dirname(__FILE__),'smart_ps.rb')

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class TransaxGateway < SmartPs
      def api_url 
        'https://secure.nelixtransax.net/api/transact.php'
      end
      
      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['US']
      
      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      
      # The homepage URL of the gateway
      self.homepage_url = 'https://www.nelixtransax.com/'
      
      # The name of the gateway
      self.display_name = 'NELiX TransaX'

    end
    TransaXGateway = TransaxGateway
  end
end

