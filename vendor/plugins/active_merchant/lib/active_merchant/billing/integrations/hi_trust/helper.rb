module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module HiTrust
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          
          # Transaction types
          # * Auth
          # * AuthRe
          # * Capture
          # * CaptureRe
          # * Refund
          # * RefundRe
          # * Query
          def initialize(order, account, options = {})
            super  
            # Perform an authorization by default
            add_field('Type', 'Auth')
            
            # Capture the payment right away
            add_field('depositflag', '1')
            
            # Disable auto query - who knows what it does?
            add_field('queryflag', '1')
            
            add_field('orderdesc', 'Store purchase')
          end
          
          mapping :account, 'storeid'
          mapping :amount, 'amount'
          
          def amount=(money)
            cents = money.respond_to?(:cents) ? money.cents : money 

            if money.is_a?(String) or cents.to_i < 0
              raise ArgumentError, 'money amount must be either a Money object or a positive integer in cents.' 
            end
            
            add_field(mappings[:amount], cents)
          end
          # Supported currencies include:
          # * CNY：Chinese Yuan (Renminbi)
          # * TWD：New Taiwan Dollar 
          # * HKD：Hong Kong Dollar 
          # * USD：US Dollar 
          # * AUD：Austrian Dollar 
          mapping :currency, 'currency'
        
          mapping :order, 'ordernumber'
          mapping :description, 'orderdesc'

          mapping :notify_url, 'merUpdateURL'
          mapping :return_url, 'returnURL'
        end
      end
    end
  end
end