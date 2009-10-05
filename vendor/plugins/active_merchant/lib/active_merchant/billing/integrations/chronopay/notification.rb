module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Chronopay
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          def complete?
            status == 'Completed'
          end

          # Status of transaction. List of possible values:
          # <tt>onetime – one time payment has been made, no repayment required;</tt>::
          # <tt>initial – first payment has been made, repayment required in corresponding period;</tt>::
          # <tt>decline – charge request has been rejected;</tt>::
          # <tt>rebill – repayment has been made together with initial transaction;</ttt>::
          # <tt>cancel – repayments has been disabled;</tt>::
          # <tt>expire – customer’s access to restricted zone membership has been expired;</tt>::
          # <tt>refund – request to refund has been received;</tt>::
          # <tt>chargeback – request to chargeback has been received.</tt>::
          # 
          # This implementation of Chronopay does not support subscriptions.
          # The status codes used are matched to the status codes that Paypal
          # sends.  See Paypal::Notification#status for more details
          def status
            case params['transaction_type']
            when 'onetime'
              'Completed'
            when 'refund'
              'Refunded'
            when 'chargeback'
              'Reversed'
            else
              'Failed'
            end
          end

          # Unique ID of transaction
          def transaction_id
            params['transaction_id']
          end

          # Unique ID of customer
          def customer_id
            params['customer_id']
          end

          # Unique ID of Merchant’s web-site
          def site_id 
            params['site_id']
          end

          # ID of a product that was purchased
          def product_id
            params['product_id']
          end

          # Language
          def language
            params['language']
          end

          def received_at
            Time.parse("#{date} #{time}") unless date.blank? || time.blank?
          end

          # Date of transaction in MM/DD/YYYY format
          def date 
            params['date']
          end

          # Time of transaction in HH:MM:SS format
          def time
            params['time']
          end

          # The customer's full name
          def name
            params['name']
          end

          # The customer's email address
          def email
            params['email']
          end

          # The customer's street address
          def street
            params['street']
          end

          # The customer's country - 3 digit country code
          def country
            params['country']
          end

          # The customer's city     
          def city
            params['city']
          end

          # The customer's zip
          def zip
            params['zip']
          end

          # The customer's state.  Only useful for US Customers
          def state
            params['state']
          end

          # Customer’s login for restricted access zone of Merchant’s Web-site
          def username
            params['username']
          end

          # Customer's password for restricted access zone of Merchant’s Web-site, as chosen
          def password
            params['password']
          end

          # The item id passed in the first custom parameter
          def item_id
            params['cs1']
          end

          # Additional parameter
          def custom2
            params['cs2']
          end

          # Additional parameter
          def custom3
            params['cs3']
          end

          # The currency the purchase was made in
          def currency
            params['currency']
          end

          # the money amount we received in X.2 decimal.
          def gross
            params['total']
          end

          def test?
            date.blank? && time.blank? && transaction_id.blank?
          end

          def acknowledge
            true
          end
        end
      end
    end
  end
end
