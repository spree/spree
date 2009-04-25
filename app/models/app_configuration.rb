class AppConfiguration < Configuration

  MAIL_AUTH = ['none', 'plain', 'login', 'cram_md5']
  SECURE_CONNECTION_TYPES = ['None','SSL','TLS']

  preference :site_name, :string, :default => 'Spree Demo Site'
  preference :site_url, :string, :default => 'demo.spreecommerce.com'
  preference :enable_mail_delivery, :boolean, :default => false
  preference :mail_host, :string, :default => 'localhost'
  preference :mail_domain, :string, :default => 'localhost'
  preference :mail_port, :integer, :default => 25
  preference :mail_auth_type, :string, :default => MAIL_AUTH[0] 
  preference :smtp_username, :string
  preference :smtp_password, :string
  preference :secure_connection_type, :string, :default => SECURE_CONNECTION_TYPES[0] 
  preference :mails_from, :string
  preference :mail_bcc, :string
  preference :order_from, :string, :default => "orders@example.com"
  preference :order_bcc, :string
  preference :store_cc, :boolean, :default => false
  preference :store_cvv, :boolean, :default => false
  preference :default_locale, :string, :default => 'en-US'
  preference :allow_locale_switching, :boolean, :default => true
  preference :default_country_id, :integer, :default => 214
  preference :allow_backorders, :boolean, :default => true
  preference :allow_backorder_shipping, :boolean, :default => false # should only be true if you don't need to track inventory
  preference :show_descendents, :boolean, :default => true
  preference :show_zero_stock_products, :boolean, :default => true
  preference :orders_per_page, :integer, :default => 15   
  preference :admin_products_per_page, :integer, :default => 10 
  preference :products_per_page, :integer, :default => 10
  preference :default_tax_category, :string, :default => nil # Use the name (exact case) of the tax category if you wish to specify
  preference :admin_interface_logo, :string, :default => "spree/spree.jpg"
  preference :allow_ssl_in_production, :boolean, :default => true
  preference :allow_ssl_in_development_and_test, :boolean, :default => false
  preference :google_analytics_id, :string, :default => '12312312' # Replace with real Google Analytics Id 
  preference :allow_guest_checkout, :boolean, :default => true 

  validates_presence_of :name
  validates_uniqueness_of :name
end
