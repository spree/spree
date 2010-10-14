class AppConfiguration < Configuration

  preference :site_name, :string, :default => 'Spree Demo Site'
  preference :site_url, :string, :default => 'demo.spreecommerce.com'
  preference :store_cc, :boolean, :default => false
  preference :store_cvv, :boolean, :default => false
  preference :default_locale, :string, :default => 'en'
  preference :allow_locale_switching, :boolean, :default => true
  preference :default_country_id, :integer, :default => 214
  preference :allow_backorders, :boolean, :default => true
  preference :allow_backorder_shipping, :boolean, :default => false # should only be true if you don't need to track inventory
  preference :track_inventory_levels, :boolean, :default => true # will not track on_hand values for variants /products
  preference :create_inventory_units, :boolean, :default => true # should only be false when track_inventory_levels is false, also disables RMA's
  preference :show_descendents, :boolean, :default => true
  preference :show_zero_stock_products, :boolean, :default => true
  preference :orders_per_page, :integer, :default => 15
  preference :admin_products_per_page, :integer, :default => 10
  preference :admin_pgroup_preview_size, :integer, :default => 10
  preference :products_per_page, :integer, :default => 10
  preference :logo, :string, :default => '/images/admin/bg/spree_50.png'
  preference :stylesheets, :string, :default => 'screen' # Comma separate multiple stylesheets, e.g. 'screen,mystyle'
  preference :admin_interface_logo, :string, :default => "admin/bg/spree_50.png"
  preference :allow_ssl_in_production, :boolean, :default => true
  preference :allow_ssl_in_development_and_test, :boolean, :default => false
  preference :allow_guest_checkout, :boolean, :default => true
  preference :allow_anonymous_checkout, :boolean, :default => false
  preference :alternative_billing_phone,  :boolean, :default => false # Request extra phone for bill addr
  preference :alternative_shipping_phone, :boolean, :default => false # Request extra phone for ship addr
  preference :shipping_instructions,      :boolean, :default => false # Request instructions/info for shipping
  preference :show_price_inc_vat, :boolean, :default => false
  preference :auto_capture, :boolean, :default => false # automatically capture the creditcard (as opposed to just authorize and capture later)
  preference :address_requires_state, :boolean, :default => true # should state/state_name be required
  preference :checkout_zone, :string, :default => nil # replace with the name of a zone if you would like to limit the countries
  preference :always_put_site_name_in_title, :boolean, :default => true
  preference :cache_static_content, :boolean, :default => true
  preference :use_content_controller, :boolean, :default => true
  preference :allow_checkout_on_gateway_error, :boolean, :default => false

  validates :name, :presence => true, :uniqueness => true

end
