module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module <%= class_name %>
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          # Replace with the real mapping
          mapping :account, ''
          mapping :amount, ''
        
          mapping :order, ''

          mapping :customer, :first_name => '',
                             :last_name  => '',
                             :email      => '',
                             :phone      => ''

          mapping :billing_address, :city     => '',
                                    :address1 => '',
                                    :address2 => '',
                                    :state    => '',
                                    :zip      => '',
                                    :country  => ''

          mapping :notify_url, ''
          mapping :return_url, ''
          mapping :cancel_return_url, ''
          mapping :description, ''
          mapping :tax, ''
          mapping :shipping, ''
        end
      end
    end
  end
end
