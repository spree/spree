module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Gestpay
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          include Common
          # Valid language codes
          #   Italian		=> 1
  				#	  English		=> 2
  				#	  Spanish		=> 3
  				#	  French    => 4
  				#   Tedesco   => 5
          def initialize(order, account, options = {})
            super
            add_field('PAY1_IDLANGUAGE', 2)
          end
       
          mapping :account, 'ShopLogin'
          
          mapping :amount, 'PAY1_AMOUNT'
          mapping :currency, 'PAY1_UICCODE'
        
          mapping :order, 'PAY1_SHOPTRANSACTIONID'

          # Buyer name PAY1_CHNAME
          mapping :customer, :email => 'PAY1_CHEMAIL'
                                    
          mapping :credit_card, :number       => 'PAY1_CARDNUMBER',
                                :expiry_month => 'PAY1_EXPMONTH',
                                :expiry_year  => 'PAY1_EXPYEAR',
                                :verification_value => 'PAY1_CVV'
          
          def customer(params = {})
            add_field(mappings[:customer][:email], params[:email])
            add_field('PAY1_CHNAME', "#{params[:first_name]} #{params[:last_name]}")
          end
          
          def currency=(currency_code)
            code = CURRENCY_MAPPING[currency_code]
  					raise StandardError, "Invalid currency code #{currency_code} specified" if code.nil?
  					
  					add_field(mappings[:currency], code)
          end
          
          def form_fields
            @encrypted_data ||= get_encrypted_string
                      
            {
              'a' => @fields['ShopLogin'],
              'b' => @encrypted_data
            }
          end
          
          def get_encrypted_string
            response = ssl_get(Gestpay.service_url, encryption_query_string)
            parse_response(response)
          end
          
          def encryption_query_string
            fields = ['PAY1_AMOUNT', 'PAY1_SHOPTRANSACTIONID', 'PAY1_UICCODE']
          
            encoded_params = fields.collect{ |field| "#{field}=#{CGI.escape(@fields[field])}" }.join(DELIMITER)
          
            "#{ENCRYPTION_PATH}?a=" + CGI.escape(@fields['ShopLogin']) + "&b=" + encoded_params + "&c=" + CGI.escape(VERSION)
          end
        end
      end
    end
  end
end
