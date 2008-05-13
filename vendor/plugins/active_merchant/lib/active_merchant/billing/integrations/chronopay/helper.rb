module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Chronopay
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          self.country_format = :alpha3
          
          def initialize(order, account, options = {})
            super
            add_field('cb_type', 'p')
            add_field('language', 'EN')
          end

          # product_id
          mapping :account, 'product_id'
          # product_name
          mapping :invoice, 'product_name'
          # product_price
          mapping :amount,   'product_price'
          # product_price_currency
          mapping :currency, 'product_price_currency'

          # f_name
          # s_name
          # email
          mapping :customer, :first_name => 'f_name',
                             :last_name  => 's_name',
                             :phone      => 'phone',
                             :email      => 'email'

          # city
          # street
          # state
          # zip
          # country - The country must be a 3 digit country code
          # phone

          mapping :billing_address, :city     => 'city',
                                    :address1 => 'street',
                                    :state    => 'state',
                                    :zip      => 'zip',
                                    :country  => 'country'

          def billing_address(mapping = {})
            # Gets the country code in the appropriate format or returns what we were given
            # The appropriate format for Chronopay is the alpha 3 country code
            country_code = lookup_country_code(mapping.delete(:country))
            add_field(mappings[:billing_address][:country], country_code)
            
            countries_with_supported_states = ['USA', 'CAN']
            if !countries_with_supported_states.include?(country_code)
              mapping.delete(:state)
              add_field(mappings[:billing_address][:state], 'XX')
            end  
            mapping.each do |k, v|
              field = mappings[:billing_address][k]
              add_field(field, v) unless field.nil?
            end 
          end        

          # card_no
          # exp_month
          # exp_year
          mapping :credit_card, :number       => 'card_no',
                                :expiry_month => 'exp_month',
                                :expiry_year  => 'exp_year'

          # cb_url
          mapping :notify_url, 'cb_url'

          # cs1
          mapping :order, 'cs1'

          # cs2
          # cs3
          # decline_url
        end
      end
    end
  end
end
