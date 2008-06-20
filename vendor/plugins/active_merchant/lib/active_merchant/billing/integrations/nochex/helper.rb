module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Nochex
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          # Required Parameters
          # email
          # amount
          mapping :account, 'email'
          mapping :amount, 'amount'
        
          # Set the field status = test for testing with accounts:
          # Account             Password
          # test1@nochex.com    123456
          # test2@nochex.com    123456
          # def initialize(order, account, options = {})
          #  super
          #  add_field('status', 'test')
          # end 

          # Need to format the amount to have 2 decimal places
          def amount=(money)
            cents = money.respond_to?(:cents) ? money.cents : money
            if money.is_a?(String) or cents.to_i <= 0
              raise ArgumentError, 'money amount must be either a Money object or a positive integer in cents.'
            end
            add_field mappings[:amount], sprintf("%.2f", cents.to_f/100)
          end
          
          # Optional Parameters
          # ordernumber
          mapping :order, 'ordernumber'

          # firstname
          # lastname
          # email_address_sender
          mapping :customer, :first_name => 'firstname',
                             :last_name  => 'lastname',
                             :email      => 'email_address_sender'

          # town
          # firstline
          # county
          # postcode
          mapping :billing_address, :city     => 'town',
                                    :address1 => 'firstline',
                                    :state    => 'county',
                                    :zip      => 'postcode'

          # responderurl 
          mapping :notify_url, 'responderurl'

          # returnurl
          mapping :return_url, 'returnurl'
          
          # cancelurl
          mapping :cancel_return_url, 'cancelurl'
          
          # description
          mapping :description, 'description'

          # Currently unmapped
          # logo
        end
      end
    end
  end
end
