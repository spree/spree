require 'pp'
require 'yajl/json_gem'
require 'stringio'
require 'cgi'

module Spree
  module Resources
    module Helpers
      STATUSES = {
        200 => '200 OK',
        201 => '201 Created',
        202 => '202 Accepted',
        204 => '204 No Content',
        301 => '301 Moved Permanently',
        302 => '302 Found',
        307 => '307 Temporary Redirect',
        304 => '304 Not Modified',
        401 => '401 Unauthorized',
        403 => '403 Forbidden',
        404 => '404 Not Found',
        409 => '409 Conflict',
        422 => '422 Unprocessable Entity',
        500 => '500 Server Error'
      }

      DefaultTimeFormat = "%B %-d, %Y".freeze

      def post_date(item)
        strftime item[:created_at]
      end

      def strftime(time, format = DefaultTimeFormat)
        attribute_to_time(time).strftime(format)
      end

      def gravatar_for(login)
        %(<img height="16" width="16" src="%s" />) % gravatar_url_for(login)
      end

      def gravatar_url_for(login)
        # TODO: Fix this.
        return ""
        md5 = AUTHORS[login.to_sym]
        default = "https://a248.e.akamai.net/assets.github.com%2Fimages%2Fgravatars%2Fgravatar-user-420.png"
        "https://secure.gravatar.com/avatar/%s?s=20&d=%s" %
          [md5, default]
      end

      def headers(status, head = {})
        css_class = (status == 201 || status == 204 || status == 404) ? 'headers no-response' : 'headers'
        lines = ["Status: #{STATUSES[status]}"]

        %(<pre class="#{css_class}"><code>#{lines * "\n"}</code></pre>\n)
      end

      def json(key)
        hash = case key
          when Hash
            h = {}
            key.each { |k, v| h[k.to_s] = v }
            h
          when Array
            key
          else Resources.const_get(key.to_s.upcase)
        end

        hash = yield hash if block_given?

        %(<pre class="highlight"><code class="language-javascript">) +
          JSON.pretty_generate(hash) + "</code></pre>"
      end

      def ruby(&block)
        %(<pre class="highlight"><code class="language-ruby">) +
        block.call + "</code></pre>"
      end

      def link_to(text, link)
        if link.is_a?(Symbol)
          url = LINKS[link]
          raise "No link found for #{link}" unless url
        else
          url = link
        end
        "<a href='#{url}'>#{text}</a>"
      end

      LINKS = {}
      LINKS[:core] = "/developer/core/"
      LINKS[:products] = LINKS[:core] + "products"
      LINKS[:variants] = LINKS[:products] + "#variants"
      LINKS[:prices] = LINKS[:core] + "#prices"
      LINKS[:orders] = LINKS[:core] + "orders"
      LINKS[:line_items] = LINKS[:orders] + "#line-items"
      LINKS[:adjustments] = LINKS[:core] + "adjustments"
      LINKS[:payments] = LINKS[:core] + "payments"
      LINKS[:calculators] = LINKS[:core] + "calculators"
      LINKS[:taxation] = LINKS[:core] + "taxation"
      LINKS[:shipping] = LINKS[:core] + "shipping"
      LINKS[:addresses] = LINKS[:core] + "addresses"
      LINKS[:zones] = LINKS[:addresses] + "#zones"
      LINKS[:promotions] = LINKS[:core] + "promotions"
      LINKS[:activators] = LINKS[:core] + "activators"
      LINKS[:preferences] = LINKS[:core] + "preferences"

      def warning(message)
        %(<div class='warning'>) + message + %(</div>)
      end

      def admin_only
        warning("This action is only accessible by an admin user.")
      end

      def not_found
        headers(404) + json(:error => "The resource you were looking for could not be found.")
      end

      def authorization_failure
        headers(401) + json(:error => "You are not authorized to perform that action.")
      end

      def text_html(response, status, head = {})
        hs = headers(status, head.merge('Content-Type' => 'text/html'))
        res = CGI.escapeHTML(response)
        hs + %(<pre class="highlight"><code>) + res + "</code></pre>"
      end
    end

    USER =
      {
        "id"=>1,
        "email"=>"spree@example.com",
        "login"=>"spree@example.com",
        "spree_api_key"=>nil,
        "created_at"=>"Fri, 01 Feb 2013 20:38:57 UTC +00:00",
        "updated_at"=>"Fri, 01 Feb 2013 20:38:57 UTC +00:00"
      }

    UPDATED_USER = USER.merge({"spree_api_key" => "A13adsfq234",
      "updated_at" => "Fri, 01 Feb 2013 20:40:57 UTC +00:00"})

    IMAGE =
       {"id"=>1,
        "position"=>1,
        "attachment_content_type"=>"image/jpg",
        "attachment_file_name"=>"ror_tote.jpeg",
        "type"=>"Spree::Image",
        "attachment_updated_at"=>nil,
        "attachment_width"=>360,
        "attachment_height"=>360,
        "alt"=>nil,
        "viewable_type"=>"Spree::Variant",
        "viewable_id"=>1}

    OPTION_VALUE =
      {
        "id"=>1,
        "name"=>"Small",
        "presentation"=>"S",
        "option_type_name"=>"tshirt-size",
        "option_type_id"=>1
      }

    VARIANT =
       {
         "id"=>1,
          "name"=>"Ruby on Rails Tote",
          "count_on_hand"=>10,
          "sku"=>"ROR-00011",
          "price"=>"15.99",
          "weight"=>nil,
          "height"=>nil,
          "width"=>nil,
          "depth"=>nil,
          "is_master"=>true,
          "cost_price"=>"13.0",
          "permalink"=>"ruby-on-rails-tote",
          "option_values"=> [OPTION_VALUE],
          "images"=> [IMAGE],
       }

    PRODUCT_PROPERTY =
      {
        "id"=>1,
        "product_id"=>1,
        "property_id"=>1,
        "value"=>"Tote",
        "property_name"=>"bag_type"
       }

    NEW_PRODUCT_EVENT =
      {
        "event" => 'product:new',
        "event_id" => '510bfe8e7575e41e41000017',
        "payload" => {
          "id"=>1,
          "name"=>"Example product",
          "description"=> "Description",
          "price"=>"15.99",
          "available_on"=>"2012-10-17T03:43:57Z",
          "permalink"=>"ruby-on-rails-tote",
          "count_on_hand"=>10,
          "meta_description"=>nil,
          "meta_keywords"=>nil }
      }

    NEW_PRODUCT_EVENT_RESPONSE = {
      "event_id" => '510bfe8e7575e41e41000004',
      "result" => 'OK',
      "details" => {
        "message" => "Product Added"
      }
    }

    NEW_PRODUCT_PUSH =
      {
        "event"=> 'product:new',
        "id"=>1123,
        "name"=>"Example product",
        "description"=> "Description",
        "price"=>"15.99",
        "available_on"=>"2012-10-17T03:43:57Z",
        "permalink"=>"ruby-on-rails-tote",
        "count_on_hand"=>10,
        "meta_description"=>nil,
        "meta_keywords"=>nil
      }

    NEW_PRODUCT_PUSH_RESPONSE =
      {
        "event_id"=> 'guid',
        "result" => 'accepted',
        'payload' => NEW_PRODUCT_PUSH
      }

    UPDATE_PRODUCT_EVENT =
      {
        "event" => 'product:update',
        "event_id" => '510bfe8e7575e41e41000017',
        "payload" => {
          "id"=>1,
          "name"=>"Example product",
          "description"=> "Description",
          "price"=>"15.99",
          "available_on"=>"2012-10-17T03:43:57Z",
          "permalink"=>"ruby-on-rails-tote",
          "count_on_hand"=>10,
          "meta_description"=>nil,
          "meta_keywords"=>nil }
    }

    UPDATE_PRODUCT_EVENT_RESPONSE = {
      "event_id" => '510bfe8e7575e41e41000004',
      "result" => 'OK',
      "details" => {
        "message" => "Product Updated"
      }
    }

    PRODUCT =
      {
        "id"=>1,
        "name"=>"Example product",
        "description"=> "Description",
        "price"=>"15.99",
        "available_on"=>"2012-10-17T03:43:57Z",
        "permalink"=>"ruby-on-rails-tote",
        "count_on_hand"=>10,
        "meta_description"=>nil,
        "meta_keywords"=>nil,
        "variants"=> [VARIANT],
        "product_properties"=> [PRODUCT_PROPERTY]
      }

    PAYMENT_METHOD =
      {
        "id"=>732545999,
        "name"=>"Check",
        "description"=>"Pay by check."
      }


    ORDER_PAYMENT =
      {
        "id"=>1,
        "amount"=>"10.00",
        "state"=>"checkout",
        "payment_method_id"=>1,
        "payment_method" => PAYMENT_METHOD
      }

    NEW_PAYMENT_EVENT =
      {
        "event" => 'payment:new',
        "event_id" => '510bfe8e7575e41e41000017',
        "payload" => {
          "id"=>1,
          "amount"=>"10.00",
          "state"=>"checkout",
          "payment_method_id"=>1 }
      }

    NEW_PAYMENT_EVENT_RESPONSE = {
      "event_id" => '510bfe8e7575e41e41000004',
      "result" => 'OK',
      "details" => {
        "message" => "Payment Received"
      }
    }

    ORDER =
      {
        "id"=>1,
        "number"=>"R335381310",
        "item_total"=>"0.0",
        "total"=>"0.0",
        "state"=>"cart",
        "adjustment_total"=>"-12.0",
        "user_id"=>nil,
        "created_at"=>"2012-10-24T01:02:25Z",
        "updated_at"=>"2012-10-24T01:02:25Z",
        "completed_at"=>nil,
        "payment_total"=>"0.0",
        "shipment_state"=>nil,
        "payment_state"=>nil,
        "email"=>nil,
        "special_instructions"=>nil,
      }


    ADJUSTMENT =
    {
      "id" => 1073043775,
      "source_type" => "Spree::Order",
      "source_id" => 1,
      "adjustable_type" => "Spree::Order",
      "adjustable_id" => 1,
      "originator_type" => "Spree::PromotionAction",
      "originator_id" => 1,
      "amount" => "-12.0",
      "label" => "Promotion (test)",
      "mandatory" => false,
      "locked" => false,
      "eligible" => true,
      "created_at" => "2012-10-24T01:02:25Z",
      "updated_at" => "2012-10-24T01:02:25Z"
    }

    line_item_variant = VARIANT

    LINE_ITEM =
      {
        "id"=>1,
        "quantity"=>1,
        "price"=>"19.99",
        "variant_id"=>1,
        "variant" => line_item_variant
      }

    LINE_ITEM2 =
      {
        "id"=>2,
        "quantity"=>2,
        "price"=>"19.99",
        "variant_id"=>1,
        "variant" => line_item_variant
      }

    PAYMENT =
      {
        "id"=>1,
        "source_type"=>"Spree::CreditCard",
        "source_id"=>1,
        "amount"=>"10.00",
        "payment_method_id"=>1,
        "response_code"=>"12345",
        "state"=>"checkout",
        "avs_response"=>nil,
        "created_at"=>"2012-10-24T23:26:23Z",
        "updated_at"=>"2012-10-24T23:26:23Z"
      }

    SHIPPING_METHOD =
      {
        "name" => "UPS Ground",
        "zone_id" => 1,
        "shipping_category_id" => 1
      }

    SHIPMENT =
      {
        "id"=>1,
        "tracking"=>nil,
        "number"=>"H123456789",
        "cost"=>"5.0",
        "shipped_at"=>nil,
        "state"=>"pending",
        "order_id"=>"R1234567",
        "shipping_method"=> SHIPPING_METHOD
      }

    temp = SHIPMENT.merge({
      "tracking" => "UPS1234566",
      "shipped_at" => Time.now.to_s,
      "state" => "shipped"
    })
    temp.delete('shipping_method')
    temp.delete('id')
    PUSH_SHIPMENT_CONFIRMATION = temp

    PUSH_SHIPMENT_RESPONSE = {
      'event_id' => 'guid',
      'result' => 'accepted',
      'payload' => PUSH_SHIPMENT_CONFIRMATION
    }

    READY_SHIPMENT = SHIPMENT.merge({"state" => "ready_to_ship"})

    SHIPPED_SHIPMENT = SHIPMENT.merge({"state" => "shipped"})

    ORDER_SHOW = ORDER.merge({
      "line_items" => [LINE_ITEM],
      "payments" => [PAYMENT],
      "shipments" => [SHIPMENT],
      "adjustments" => [ADJUSTMENT]

    })

    ORDER_SHOW2 = ORDER.merge({
      "line_items" => [LINE_ITEM2],
      "payments" => [PAYMENT],
      "shipments" => [SHIPMENT],
      "adjustments" => [ADJUSTMENT]

    })

    EVENT = {
      "event" => 'event:name',
      "event_id" => 'guid',
      "payload" => {
        "order" => "..."
      }
    }

    EVENT_RESPONSE = {
      "event_id" => 'guid',
      "result" => 'ok',
      "details" => {
        "message" => "..."
      }
    }

    NEW_ORDER_EVENT = {
      "event" => 'order:new',
      "event_id" => '510bfe8e7575e41e41000001',
      "payload" => {
        "order" => ORDER_SHOW
      }
    }

    NEW_ORDER_RESPONSE = {
      "event_id" => '510bfe8e7575e41e41000001',
      "result" => 'ok',
      "details" => {
        "message" => "Order sent to warehouse"
      }
    }

    UPDATED_ORDER_EVENT = {
      "event" => 'order:updated',
      "event_id" => '510bfe8e7575e41e41000002',
      "payload" => {
        "order" => ORDER_SHOW2
      }
    }

    UPDATED_ORDER_RESPONSE = {
      "event_id" => '510bfe8e7575e41e41000002',
      "result" => 'ok',
      "details" => {
        "message" => "Update sent to warehouse"
      }
    }

    CANCELLED_ORDER_EVENT = {
      "event" => 'order:cancelled',
      "event_id" => '510bfe8e7575e41e41000003',
      "payload" => {
        "order" => ORDER
      }
    }

    CANCELLED_ORDER_RESPONSE = {
      "event_id" => '510bfe8e7575e41e41000003',
      "result" => 'ok',
      "details" => {
        "message" => "Order cancellation sent to warehouse"
      }
    }

    NEW_USER_EVENT = {
      "event" => 'create:user',
      "event_id" => '510bfe8e7575e41e41000017',
      "payload" => {
        "user" => USER
      }
    }

    NEW_USER_RESPONSE = {
      "event_id" => '510bfe8e7575e41e41000017',
      "result" => 'ok',
      "details" => {
        "message" => "User Account Created"
      }
    }

    UPDATED_USER_EVENT = {
      "event" => 'update:event',
      "event_id" => '510bfe8e7575e41e41000018',
      "payload" => {
        "user" => UPDATED_USER
      }
    }

    UPDATED_USER_RESPONSE = {
      "event_id" => '510bfe8e7575e41e41000018',
      "result" => 'ok',
      "details" => {
        "message" => "User Account Updated"
      }
    }
    SHIPMENT_READY_EVENT = {
      "event" => 'shipment:ready',
      "event_id" => '510bfe8e7575e41e41000004',
      "payload" => {
        "shipment" => READY_SHIPMENT
      }
    }

    SHIPMENT_READY_RESPONSE = {
      "event_id" => '510bfe8e7575e41e41000004',
      "result" => 'ok',
      "details" => {
        "message" => "Shipment sent to warehouse for fulfillment"
      }
    }

    SHIPMENT_CONFIRMATION_EVENT = {
      "event" => 'shipment:confirmed',
      "event_id" => '510bfe8e7575e41e41000005',
      "payload" => {
        "shipment" => SHIPPED_SHIPMENT
      }
    }

    SHIPMENT_CONFIRMATION_RESPONSE = {
      "event_id" => '510bfe8e7575e41e41000005',
      "result" => 'ok',
      "details" => {
        "message" => "Shipping Confirmation email Sent"
      }
    }

    ORDER_SHOW_ADDRESS_STATE = ORDER.merge({
      "state" => "address",
      "line_items" => [LINE_ITEM]
    })

    ORDER_SHOW_DELIVERY_STATE = ORDER.merge({
      "shipments"=>[{
        "id"=>1,
        "tracking"=>"FOOBAR",
        "number"=>"H32535710153",
        "cost"=>"5.0",
        "state"=>"pending",
        "order_id"=>"R366605801",
        "stock_location_name"=>"default",
        "shipping_rates"=>[{
          "id"=>1,
          "cost"=>"5.0",
          "selected"=>true,
          "shipment_id"=>1,
          "shipping_method_id"=>1
        }, {
          "id"=>3,
          "cost"=>"10.0",
          "selected"=>false,
          "shipment_id"=>1,
          "shipping_method_id"=>2
        }, {
          "id"=>2,
          "cost"=>"15.0",
          "selected"=>false,
          "shipment_id"=>1,
          "shipping_method_id"=>3
        }],
        "shipping_method"=>{
          "name"=>"UPS Ground (USD)"
        },
      }],
      "state" => "delivery"
    })

    ORDER_SHOW_PAYMENT_STATE = ORDER.merge({
      "payment_methods" => [PAYMENT_METHOD],
      "state" => "payment"
    })

    ORDER_SHOW_CONFIRM_STATE = ORDER.merge({
      "state" => "confirm"
    })

    ORDER_SHOW_COMPLETE_STATE = ORDER.merge({
      "state" => "complete"
    })

    ADDRESS_COUNTRY =
      {
        "id"=>1,
        "iso_name"=>"UNITED STATES",
        "iso"=>"US",
        "iso3"=>"USA",
        "name"=>"United States",
        "numcode"=>1
      }

    ADDRESS_STATE =
      {
        "abbr"=>"NY",
        "country_id"=>1,
        "id"=>1,
        "name"=>"New York"
      }

    ADDRESS =
      {
        "id"=>1,
        "firstname"=>"Spree",
        "lastname"=>"Commerce",
        "address1"=>"1 Someplace Lane",
        "address2"=>"Suite 1",
        "city"=>"Bethesda",
        "zipcode"=>"16804",
        "phone"=>"123.4567.890",
        "company"=>nil,
        "alternative_phone"=>nil,
        "country_id"=>1,
        "state_id"=>1,
        "state_name"=>nil,
        "country"=> ADDRESS_COUNTRY,
        "state" => ADDRESS_STATE
      }

    COUNTRY_STATE = { "state"=> ADDRESS_STATE }

    COUNTRY =
      {
        "id"=>1,
        "iso_name"=>"UNITED STATES",
        "iso"=>"US",
        "iso3"=>"USA",
        "name"=>"United States",
        "numcode"=>1,
        "states"=> [COUNTRY_STATE]
      }

    STATE =
      {
        "abbr"=>"NY",
        "country_id"=>1,
        "id"=>1,
        "name"=>"New York"
      }

    TAXON =
      {
        "id"=>2,
        "name"=>"Ruby on Rails",
        "permalink"=>"brands/ruby-on-rails",
        "position"=>1,
        "parent_id"=>1,
        "taxonomy_id"=>1
      }

    SECONDARY_TAXON =
      {
        "id"=>3,
        "name"=>"T-Shirts",
        "permalink"=>"brands/ruby-on-rails/t-shirts",
        "position"=>1,
        "parent_id"=>2,
        "taxonomy_id"=>1
      }

    TAXON_WITH_CHILDREN = TAXON.merge(:taxons => [SECONDARY_TAXON])
    TAXON_WITHOUT_CHILDREN = TAXON.merge(:taxons => [])

    TAXONOMY =
     {
       "id"=>1,
       "name"=>"Brand",
       "root"=> TAXON_WITH_CHILDREN
     }

    NEW_TAXONOMY =
      {
        "id" => 1,
        "name" => "Brand",
        "root" => TAXON_WITHOUT_CHILDREN
      }

    ZONE_MEMBER =
      {
        "id"=>1,
        "name"=>"United States",
        "zoneable_type"=>"Spree::Country",
        "zoneable_id"=>1,
      }

    ZONE =
      {
        "id"=>1,
        "name"=>"America",
        "description"=>"The US",
        "zone_members"=> [ZONE_MEMBER]
      }

    RETURN_AUTHORIZATION =
      {
        "id"=>1,
        "number"=>"12345",
        "state"=>"authorized",
        "amount"=> 14.22,
        "order_id"=>14,
        "reason"=>"Didn't fit",
        "created_at"=>"2012-10-24T23:26:23Z",
        "updated_at"=>"2012-10-24T23:26:23Z"
      }

    STOCK_LOCATION =
      {
        "id"=>1,
        "name"=>"default",
        "address1"=>"7735 Old Georgetown Road",
        "address2"=>"Suite 510",
        "city"=>"Bethesda",
        "state_id"=>26,
        "country_id"=>49,
        "zipcode"=>"20814",
        "phone"=>"",
        "active"=>true
      }

    STOCK_ITEM =
      {
        "id"=>1,
        "count_on_hand"=>10,
        "backorderable"=>true,
        "lock_version"=>1,
        "stock_location_id"=>1,
        "variant_id"=>1
      }

    STOCK_MOVEMENT =
      {
        "id"=>1,
        "quantity"=>10,
        "action"=>"received",
        "stock_item_id"=>1
      }
    end
end

include Spree::Resources::Helpers
