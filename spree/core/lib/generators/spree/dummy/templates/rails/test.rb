Dummy::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # The test environment is used exclusively to run your application's
  # test suite. You never need to work with it otherwise. Remember that
  # your test database is "scratch space" for the test suite and is wiped
  # and recreated between test runs. Don't rely on the data there!
  config.cache_classes = true

  # Configure static asset server for tests with Cache-Control for performance
  config.public_file_server.enabled = true
  config.public_file_server.headers = { 'Cache-Control' => 'public, max-age=3600' }

  # Show full error reports and disable caching
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  config.eager_load = false

  # Raise exceptions instead of rendering exception templates
  config.action_dispatch.show_exceptions = false

  # Disable request forgery protection in test environment
  config.action_controller.allow_forgery_protection    = false

  # A `before_action ... only: [:gone_action]` naming an action that no longer
  # exists makes Rails refuse every request to that controller. Enabled here so
  # the suite sees it, as every real Spree app does.
  config.action_controller.raise_on_missing_callback_actions = true

  # Fail a spec that looks up a translation key that does not exist.
  config.i18n.raise_on_missing_translations = true

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :test
  ActionMailer::Base.default from: "spree@example.com"
  # Store uploaded files on the local file system in a temporary directory
  config.active_storage.service = :test

  # Print deprecation notices to the stderr
  config.active_support.deprecation = :stderr

  # Spree's own code and specs must not call these deprecated APIs. A spec
  # covering one on purpose stubs Spree::Deprecation.warn or silences it.
  config.active_support.disallowed_deprecation = :raise
  config.active_support.disallowed_deprecation_warnings = [
    /Spree\.t is deprecated/,
    /Spree::Product#(master|variants_including_master) is deprecated/,
    /Spree::(Order|Cart)#(shipment_total|promo_total|item_count|shipping_discount) is deprecated/,
    /Spree::Order#finalize! is deprecated/,
    /Spree::Payment#state=? is deprecated/,
    /Spree::Payment#(process|authorize|purchase|capture|void_transaction)! is deprecated/,
    /Spree::(Category|Product)#classifications is deprecated/,
    /Spree::Product#taxons=? is deprecated/,
    /Spree::Promotion::Rules::Category#taxon/,
    /Spree::Fulfillment#(add_)?shipping_method is deprecated/,
    /Spree::Stock::Package#shipping_methods is deprecated/,
    /Calling Spree::(Carts::AddItem|StockReservations::(Reserve|Extend)) with order: is deprecated/,
    /Spree::Config\[:admin_url\] is deprecated/,
    /private_metadata=? is deprecated/,
    /Spree::Pricing::Resolver is deprecated/,
    /Spree::Invitation#accept! is deprecated/,
    /`preference :\w+, in:` is deprecated/
  ]

  config.active_job.queue_adapter = :test

  config.cache_store = :null_store

  # Spree encrypts secrets at rest (webhook signing keys, OAuth tokens) only when
  # Active Record encryption is configured, so the suite configures it like a
  # production app would.
  config.active_record.encryption.primary_key = 'spree-test-primary-key'
  config.active_record.encryption.deterministic_key = 'spree-test-deterministic-key'
  config.active_record.encryption.key_derivation_salt = 'spree-test-key-derivation-salt'

  routes.default_url_options = { host: 'localhost', port: 3000 }
end
