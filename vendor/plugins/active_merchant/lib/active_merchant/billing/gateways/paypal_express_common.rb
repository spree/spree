module ActiveMerchant
  module Billing
    module PaypalExpressCommon
      def self.included(base)
        base.cattr_accessor :test_redirect_url
        base.cattr_accessor :live_redirect_url
        base.live_redirect_url = 'https://www.paypal.com/cgibin/webscr?cmd=_express-checkout&token='
      end
      
      def redirect_url
        test? ? test_redirect_url : live_redirect_url
      end
      
      def redirect_url_for(token, options = {})
        options = {:review => true}.update(options)
        options[:review] ? "#{redirect_url}#{token}" : "#{redirect_url}#{token}&useraction=commit"
      end
    end
  end
end