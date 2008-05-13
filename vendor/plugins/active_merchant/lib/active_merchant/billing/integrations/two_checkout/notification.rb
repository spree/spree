require 'net/http'
require 'base64'
require 'digest/md5'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module TwoCheckout
        class Notification < ActiveMerchant::Billing::Integrations::Notification
        #  order_number	2Checkout.com order number
        #   	card_holder_name	Card holder's name
        #   	street_address	Card holder's address
        #   	city	Card holder's city
        #   	state	Card holder's state
        #   	zip	Card holder's zip
        #   	country	Card holder's country
        #   	email	Card holder's email
        #   	phone	Card holder's phone
        #   	credit_card_processed	Y if successful, K if waiting for approval
        #   	total	 Total purchase amount
        #   	ship_name	Shipping information
        #   	ship_street_address	Shipping information
        #   	ship_city	Shipping information
        #   	ship_state	Shipping information
        #   	ship_zip	 Shipping information
        #   	ship_country	Shipping information
        #   	product_id	2Checkout product ID for purchased items will append a number if more than one item. 
        #  ex. product_id,product_id1,product_id2
        #   	quantity	quantity of corresponding product will append a number if more than one item.
        #  ex. quantity,quantity1,quantity2
        #   	merchant_product_id	 your product ID for purchased items will append a number if more than one item.
        #  ex. merchant_product_id,merchant_product_id1,merchant_product_id2
        #   	product_description	your description for purchased items will append a number if more than one item.
        #  ex. product_description,product_description1,product_description2
          
          def currency
            'USD'
          end
          
          def complete?
            status == 'Completed'
          end 

          def item_id
            params['cart_order_id']
          end

          def transaction_id
            params['order_number']
          end

          def received_at
            params['']
          end

          def payer_email
            params['email']
          end
         
          def receiver_email
            params['']
          end 

          # The MD5 Hash
          def security_key
            params['key']
          end

          # the money amount we received in X.2 decimal.
          def gross
            params['total']
          end

          # Was this a test transaction? # Use the hash
          def test?
            params['demo'] == 'Y'
          end

          def status
            case params['credit_card_processed']
            when 'Y'
              'Completed'
            when 'K'
              'Pending'
            else
              'Failed'
            end
          end
          
          def verify(secret)
            return false if security_key.blank?
            
            Digest::MD5.hexdigest("#{secret}#{params['sid']}#{transaction_id}#{gross}").upcase == security_key.upcase
          end
          
          def acknowledge
            true
          end
          
          private
          
          def parse(post)
            @raw = post.to_s
            for line in @raw.split('&')    
              key, value = *line.scan( %r{^(\w+)\=(.*)$} ).flatten
              params[key] = CGI.unescape(value || '')
            end
          end
          
        end
      end
    end
  end
end
