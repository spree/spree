require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Gestpay
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          include Common
          
          def complete?
            status == 'Completed'
          end 

          # The important param
          def item_id
            params['PAY1_SHOPTRANSACTIONID']
          end

          def transaction_id
            params['PAY1_BANKTRANSACTIONID']
          end

          # the money amount we received in X.2 decimal.
          def gross
            params['PAY1_AMOUNT']
          end
          
          def currency
            CURRENCY_MAPPING.index(params['PAY1_UICCODE'])
          end

          def test?
            false
          end

          def status
            case params['PAY1_TRANSACTIONRESULT']
            when 'OK'
              'Completed'
            else
              'Failed'
            end
          end

          def acknowledge
            true
          end
          
          private
          # Take the posted data and move the relevant data into a hash
          def parse(query_string)
            @raw = query_string
            
            return if query_string.blank?
            encrypted_params = parse_delimited_string(query_string)
            
            return if encrypted_params['a'].blank? || encrypted_params['b'].blank?
            @params = decrypt_data(encrypted_params['a'], encrypted_params['b'])
          end
          
          def parse_delimited_string(string, delimiter = '&', unencode_cgi = false)
            result = {}
            for line in string.split(delimiter)
              key, value = *line.scan( %r{^(\w+)\=(.*)$} ).flatten
              result[key] = unencode_cgi ? CGI.unescape(value) : value
            end
            result
          end
          
          def decrypt_data(shop_login, encrypted_string)
            response = ssl_get(Gestpay.service_url, decryption_query_string(shop_login, encrypted_string))
            encoded_response = parse_response(response)
            parse_delimited_string(encoded_response, DELIMITER, true)
          end
        
          def decryption_query_string(shop_login, encrypted_string)
            "#{DECRYPTION_PATH}?a=" + CGI.escape(shop_login) + "&b=" + encrypted_string + "&c=" + CGI.escape(VERSION)
          end
        end
      end
    end
  end
end
