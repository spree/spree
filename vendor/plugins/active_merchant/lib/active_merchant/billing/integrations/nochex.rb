require File.dirname(__FILE__) + '/nochex/helper.rb'
require File.dirname(__FILE__) + '/nochex/notification.rb'
require File.dirname(__FILE__) + '/nochex/return.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      # To start with Nochex, follow the instructions for installing 
      # ActiveMerchant as a plugin, as described on 
      # http://www.activemerchant.org/.
      # 
      # The plugin will automatically add the ActionView helper for 
      # ActiveMerchant, which will allow you to make the Nochex payments.  
      # The idea behind the helper is that it generates an invisible 
      # forwarding screen that will automatically redirect the user.  
      # So you would collect all the information about the order and then 
      # simply render the hidden form, which redirects the user to Nochex.
      # 
      # The syntax of the helper is as follows:
      # 
      #   <% payment_service_for 'order id', 'nochex_user_id',
      #                                 :amount => 50.00,
      #                                 :service => :nochex,
      #                                 :html => { :id => 'nochex-form' } do |service| %>
      #   
      #      <% service.customer :first_name => 'Cody',
      #                         :last_name => 'Fauser',
      #                         :phone => '(555)555-5555',
      #                         :email => 'cody@example.com' %>
      #   
      #      <% service.billing_address :city => 'Ottawa',
      #                                :address1 => '21 Snowy Brook Lane',
      #                                :address2 => 'Apt. 36',
      #                                :state => 'ON',
      #                                :country => 'CA',
      #                                :zip => 'K1J1E5' %>
      #   
      #      <% service.invoice '#1000' %>
      #      <% service.shipping '0.00' %>
      #      <% service.tax '0.00' %>
      #   
      #      <% service.notify_url url_for(:action => 'notify', :only_path => false) %>
      #      <% service.return_url url_for(:action => 'done', :only_path => false) %>
      #      <% service.cancel_return_url 'http://mystore.com' %>
      #    <% end %>
      #   
      # The notify_url is the URL that the Nochex IPN will be sent.  You can 
      # handle the notification in your controller action as follows:
      #   
      #   class NotificationController < ApplicationController
      #     include ActiveMerchant::Billing::Integrations
      #   
      #     def notify
      #       notification =  Nochex::Notification.new(request.raw_post)
      #       
      #       begin
      #         # Acknowledge notification with Nochex
      #         raise StandardError, 'Illegal Notification' unless notification.acknowledge
      #           # Process the payment  
      #       rescue => e
      #           logger.warn("Illegal notification received: #{e.message}")
      #       ensure
      #           head(:ok)
      #       end
      #     end
      #   end
      module Nochex
       
        mattr_accessor :service_url
        self.service_url = 'https://www.nochex.com/nochex.dll/checkout'

        mattr_accessor :notification_confirmation_url
        self.notification_confirmation_url = 'https://www.nochex.com/nochex.dll/apc/apc'

        # Simply a convenience method that returns a new 
        # ActiveMerchant::Billing::Integrations::Nochex::Notification
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