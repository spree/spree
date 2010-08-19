module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # ==== Mock Customer Information Manager (CIM) Gateway
    class AuthorizeNetCimGateway < Gateway

      class << self
        attr_accessor :force_failure
        def force_failure?
          !! @force_failure
        end
      end


      def create_customer_profile(options)
        if self.class.force_failure?
          params = {
            "messages"=>{"result_code"=>"Error", "message"=>{"code"=>"E00039", "text"=>"A duplicate record with id 945184 already exists."}}, 
          }
          ActiveMerchant::Billing::Response.new(false, "Failed to create profile.", params)
        else
          params = {"messages"=> {
            "result_code"=>"Ok", 
            "message"=>{"code"=>"I00001", "text"=>"Successful."}},
            "customer_payment_profile_id_list"=>{"numeric_string"=>"456"}, 
            "ref_id"=>"1263245498", 
            "customer_profile_id"=>"123", 
            "customer_shipping_address_id_list"=>{"numeric_string"=>"789"}, 
            "validation_direct_response_list"=>nil
          }
          ActiveMerchant::Billing::Response.new(true, "Successful.", params)
        end
      end

      def create_customer_profile_transaction(options)
        if self.class.force_failure?
          params = {
            "messages"=>{
              "result_code"=>"Error", 
              "message"=>{"code"=>"E00040", "text"=>"customerProfileId or customerPaymentProfileId not found."}
            }
          }
          ActiveMerchant::Billing::Response.new(false, "Failed to create profile.", params)
        else
          params = {
            "messages" => {
              "result_code"=>"Ok", 
              "message"=>{"code"=>"I00001", "text"=>"Successful."}
            }
          }
          if options[:transaction][:type] == :auth_only
            params["direct_response"] = {"approval_code"=>"XYZ", "purchase_order_number"=>"", "amount"=>"0.01", "transaction_type"=>"auth_only", "invoice_number"=>""}
          end       
          ActiveMerchant::Billing::Response.new(true, "Successful.", params, :authorization => '123456')
        end
      end

    end
  end
end