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

    ORDER_SHOW = ORDER.merge({
      "line_items" => [LINE_ITEM],
      "payments" => [PAYMENT],
      "shipments" => [SHIPMENT],
      "adjustments" => [ADJUSTMENT]

    })

    ORDER_SHOW_ADDRESS_STATE = ORDER.merge({
      "state" => "address",
      "line_items" => [LINE_ITEM]
    })

    ORDER_SHOW_DELIVERY_STATE = ORDER.merge({
      "shipping_methods" => [SHIPPING_METHOD],
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
    end
end

include Spree::Resources::Helpers
