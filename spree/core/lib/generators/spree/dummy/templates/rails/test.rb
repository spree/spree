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

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :test
  ActionMailer::Base.default from: "spree@example.com"
  # Store uploaded files on the local file system in a temporary directory
  config.active_storage.service = :test

  # Print deprecation notices to the stderr
  config.active_support.deprecation = :stderr

  config.active_job.queue_adapter = :test

  config.cache_store = :null_store

  routes.default_url_options = { host: 'localhost', port: 3000 }

  # An N+1 inside an API request fails the example instead of being logged,
  # so a serializer or model method that queries once per record cannot land
  # unnoticed. Wrap a deliberately repeated lookup in Prosopite.pause.
  if defined?(Prosopite)
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
      %r{/paranoia\.rb:\d+:in '[^']*destroy'}
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

    # Two `belongs_to` on one table — an order's billing and shipping
    # address, a category's image and square image — are a single lookup
    # each, but they normalize to one fingerprint, so a single record reads
    # as a repeat. The cost there is per association, not per record, which
    # is not what this guard is for.
    #
    # A real N+1 on a single-row lookup asks for a *different* row each time,
    # so the row asked for is what separates the two. The id travels in the
    # bind values rather than the SQL text; recording which rows a statement
    # asked for lets the fingerprint keep them apart while a repeat of the
    # same row still reports.
    # A lookup of one specific row: keyed by a primary key, or by the
    # (record, name) pair Active Storage uses for an attachment.

  end
end
