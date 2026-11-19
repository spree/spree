Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # The test environment is used exclusively to run your application's
  # test suite. You never need to work with it otherwise. Remember that
  # your test database is "scratch space" for the test suite and is wiped
  # and recreated between test runs. Don't rely on the data there!
  config.enable_reloading = false

  # Configure static asset server for tests with Cache-Control for performance
  config.public_file_server.enabled = true
  config.public_file_server.headers = { 'Cache-Control' => 'public, max-age=3600' }

  # Show full error reports and disable caching
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  config.eager_load = false

  # Raise unexpected exceptions; render the ones Rails maps to a status, such
  # as a 404 for an unknown route, the way production does.
  config.action_dispatch.show_exceptions = :rescuable

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

  # An N+1 inside an API request fails the example instead of being logged,
  # so a serializer or model method that queries once per record cannot land
  # unnoticed. Wrap a deliberately repeated lookup in Prosopite.pause.
  if defined?(Prosopite)
    # Hooked from Spree's own test app rather than declared in the
    # controller, so a host application that bundles Prosopite for itself is
    # never opted into Spree's guard. Prepended so the lookups made by the
    # authentication and parent callbacks are scanned too.
    config.to_prepare do
      if defined?(Spree::Api::V3::BaseController)
        Spree::Api::V3::BaseController.prepend_around_action { |_controller, action| Prosopite.scan(&action) }
      end
    end

    Prosopite.rails_logger = true
    # Raise only under RSpec, where a report belongs to the example that
    # caused it. The same dummy app serves a real server for the SDK and
    # browser suites, and there a raise becomes a 500 the client cannot act
    # on — those runs log instead. SPREE_N_PLUS_ONE_GUARD overrides either
    # way ('raise', 'log').
    running_specs = ENV.key?('TEST_ENV_NUMBER') || $PROGRAM_NAME.end_with?('rspec')
    guard_mode = ENV.fetch('SPREE_N_PLUS_ONE_GUARD') { running_specs ? 'raise' : 'log' }
    Prosopite.raise = guard_mode == 'raise'

    # The Rails cleaner keeps only the host app's frames, which hides the
    # serializer or model line that issued the repeated query.
    Prosopite.backtrace_cleaner = ActiveSupport::BacktraceCleaner.new.tap do |cleaner|
      cleaner.add_silencer { |line| line.include?('/gems/') || line.include?('/rspec') }
    end

    # The guard covers what a request reads. Writes run their callbacks one
    # record at a time by design — a `dependent: :destroy` cascade, a number
    # or uniqueness probe per created row — so statements issued under a
    # save or destroy are not reported.
    Prosopite.allow_stack_paths = [
      %r{active_record/persistence\.rb:\d+:in '[^']*#(save|save!|destroy|destroy!|touch)'},
      # A touch is a write too, and Spree overrides `touch` in its own
      # concern, so the frame is Spree's rather than Active Record's.
      %r{active_record/timestamp\.rb:\d+:in '[^']*#touch'},
      %r{/spree/publishable\.rb:\d+:in '[^']*#touch'},
      %r{/paranoia\.rb:\d+:in '[^']*destroy'},
      # Validations run before the persistence frame starts, so a uniqueness
      # or ladder probe on the row being saved needs its own entry.
      %r{active_record/validations\.rb:\d+:in '[^']*#(save|save!)'},
      # after_commit callbacks are the same per-record write work, deferred
      # until the transaction that wrote the rows ends.
      %r{active_record/transactions\.rb:\d+:in '[^']*#committed!'},
      # Locking a row re-reads it, once per row the caller is about to write.
      %r{active_record/locking/pessimistic\.rb:\d+:in '[^']*#lock!'},
      # A product payload writes each nested variant and media row through its
      # own workflow — SKU probe, option lookup, blob resolution — once per row.
      %r{/spree/products/nested_attributes\.rb:\d+:in '[^']*#(write_variant|apply_media)'},
      # A settlement is swept per currency, and each sweep writes its own payout.
      %r{/spree/seller_payouts/sweep\.rb:\d+:in '[^']*#collect_transfers'},
      # A split checkout re-sums and then places each seller's order it just
      # wrote, one workflow run per order.
      %r{/spree/carts/split_by_seller\.rb:\d+:in '[^']*#resum_totals'},
      %r{/spree/orders/complete\.rb:\d+:in '[^']*#place_sibling'},
      # Each requested line is priced, stock-checked, saved and taxed as it
      # is written.
      %r{/spree/carts/upsert_items\.rb:\d+:in '[^']*#apply_item'},
      # An import writes each row on its own, inside the request when the
      # import is set to run inline.
      %r{/spree/import_row\.rb:\d+:in '[^']*#process!'}
    ]

    # A purchase's billing and shipping addresses, and a transfer's two
    # warehouses, are two links into one table read through the same code,
    # so one record reads as a repeat. Lists still load each link in one
    # query for the whole page.
    Prosopite.ignore_queries = [
      /FROM [`"]?(spree_addresses|spree_stock_locations)[`"]? WHERE (.+ AND )?[`"]?\1[`"]?\.[`"]?id[`"]? (=|IN)/
    ]

    # Prosopite fingerprints through pg_query, which rejects SQLite's `?`
    # binds, so SQLite borrows the text normalizer written for MySQL. That
    # normalizer blanks anything double-quoted, which is a string literal in
    # MySQL but an identifier in SQLite — left alone it erases every table
    # name, collapsing unrelated queries into one fingerprint and reporting
    # a single record's distinct associations as an N+1. Re-quoting
    # identifiers as backticks first keeps table names in the fingerprint.
    Prosopite.singleton_class.prepend(Module.new do
      def fingerprint(query)
        return super unless ActiveRecord::Base.connection_db_config.adapter == 'sqlite3'

        mysql_fingerprint(query.gsub(/"([^"]*)"/) { "`#{Regexp.last_match(1)}`" })
      end
    end)
  end
end
