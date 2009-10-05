require File.dirname(__FILE__) + '/paypal'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # The PayPal gateway for PayPal Website Payments Pro Canada only supports Visa and MasterCard
    class PaypalCaGateway < PaypalGateway
      self.supported_cardtypes = [:visa, :master]
      self.supported_countries = ['CA']
      self.homepage_url = 'https://www.paypal.com/cgi-bin/webscr?cmd=_wp-pro-overview-outside'
      self.display_name = 'PayPal Website Payments Pro (CA)'
    end
  end
end
