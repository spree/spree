require File.dirname(__FILE__) + '/hi_trust/helper.rb'
require File.dirname(__FILE__) + '/hi_trust/notification.rb'
require File.dirname(__FILE__) + '/hi_trust/return.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module HiTrust 
        TEST_URL = 'https://testtrustlink.hitrust.com.tw/TrustLink/TrxReq'
        LIVE_URL = 'https://trustlink.hitrust.com.tw/TrustLink/TrxReq'
        
        def self.service_url
          ActiveMerchant::Billing::Base.integration_mode == :test ? TEST_URL : LIVE_URL
        end

        def self.notification(post)
          Notification.new(post)
        end
        
        def self.return(query_string)
          Return.new(query_string)
        end  
      end
    end
  end
end
