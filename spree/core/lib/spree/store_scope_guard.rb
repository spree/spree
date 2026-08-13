require 'request_store'

module Spree
  # Development/test tripwire for cross-store data leaks
  # (docs/plans/6.0-store-context-and-first-run-setup.md): while a guarded
  # request runs, a SELECT against a store-owned table (any spree_* table
  # carrying a store_id column) that is neither store-scoped nor id-filtered
  # is reported — that is the shape of an IDOR/cross-store leak, since every
  # controller lookup must go through a current_store association. Open-core
  # isolation rests on that discipline (row-level enforcement is not a core
  # feature), so this is the net under it.
  #
  # Never active in production — it is a correctness net for development and
  # CI, not an enforcement layer. Mode comes from
  # `Spree::Config[:store_scope_guard]` / SPREE_STORE_SCOPE_GUARD:
  # 'log' (default), 'raise', or 'off'.
  #
  # A deliberately store-less lookup (a global credential search, a
  # cross-store listing for the store switcher) opts out explicitly:
  #
  #   Spree::StoreScopeGuard.skip { Spree::ApiKey.find_by(token: token) }
  #
  # Flags live in RequestStore — like Spree::Events' disable flags — so a
  # request that leaks mid-flight cannot leave a reused server thread
  # permanently skipped or watched.
  class StoreScopeGuard
    class UnscopedQueryError < StandardError; end

    ACTIVE_KEY = :spree_store_scope_guard_active
    SKIP_KEY = :spree_store_scope_guard_skip

    # Tables that answer store-less queries by design. spree_stores is the
    # tenant root itself; the *_stores join tables are the legacy multi-store
    # bridges, filtered by their other foreign key.
    IGNORED_TABLES = %w[
      spree_stores
      spree_products_stores
      spree_promotions_stores
      spree_payment_methods_stores
    ].freeze

    class << self
      def enabled?
        watchable_environment? && mode != 'off'
      end

      # Overridable: OSS keeps the guard out of production, but a
      # multi-tenant enforcement layer may run it there as a log-mode canary.
      # Memoized — this sits on the production request path, where it must
      # answer "no" for free.
      def watchable_environment?
        return @watchable_environment if defined?(@watchable_environment)

        @watchable_environment = Rails.env.development? || Rails.env.test?
      end

      # @return [String] 'log', 'raise' or 'off'
      def mode
        Spree::Config[:store_scope_guard]
      end

      # Wraps a unit of work (an API request) in the guarded window. No-op
      # when the guard is disabled.
      def watch
        return yield unless enabled?

        install!
        previous = RequestStore.store[ACTIVE_KEY]
        RequestStore.store[ACTIVE_KEY] = true
        yield
      ensure
        RequestStore.store[ACTIVE_KEY] = previous
      end

      # Suppresses the guard for a deliberately store-less lookup.
      def skip
        previous = RequestStore.store[SKIP_KEY]
        RequestStore.store[SKIP_KEY] = true
        yield
      ensure
        RequestStore.store[SKIP_KEY] = previous
      end

      def active?
        RequestStore.store[ACTIVE_KEY] && !RequestStore.store[SKIP_KEY]
      end

      # Forgets memoized environment/schema state (specs, migrations).
      def reset!
        remove_instance_variable(:@watchable_environment) if defined?(@watchable_environment)
        @watched_tables = nil
      end

      private

      def install!
        @installed ||= begin
          ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
            check(payload) if active?
          end
          true
        end
      end

      def check(payload)
        return if payload[:cached]

        sql = payload[:sql].to_s
        # Active Record emits uppercase keywords; hand-written lowercase SQL
        # is out of scope for a tripwire.
        return unless sql.start_with?('SELECT')

        table = sql[/ FROM ["'`]?([a-z0-9_]+)/, 1]
        return if table.nil? || !watched_tables.include?(table)
        return if scoped?(sql)

        report(table, sql, payload[:name])
      end

      # Deliberately crude — parsing SQL to never false-negative is not the
      # point; catching the common leak shapes cheaply is. A statement counts
      # as scoped when it carries:
      #
      # - a store_id predicate anywhere, or
      # - any id/_id predicate: primary-key and foreign-key filters use ids
      #   that came from rows already loaded through a scoped association, or
      # - the `SELECT 1 AS one` existence shape, which is dominated by
      #   uniqueness validations on deliberately global columns (document
      #   numbers are unique across stores by design).
      #
      # What that trades away, honestly: attacker-controlled raw ids in
      # store-less finds/FK filters and `exists?` probes slip through — those
      # shapes are covered structurally (v3 resource lookups run through
      # `for_store(current_store)`). The net catches what has no structural
      # cover: secondary-key lookups (slug, number, code, email, token) and
      # unscoped scans.
      def scoped?(sql)
        # A store_id PREDICATE, not a mention — a projected column
        # (`select(:store_id)`) or a literal in a comment must not count.
        sql.match?(/\bstore_id"?\s+(=|!=|IN|IS)\s/) ||
          sql.start_with?('SELECT 1 AS one') ||
          sql.match?(/\b(id|[a-z_]+_id)"?\s+(=|!=|IN)\s/)
      end

      # Store-owned tables, derived from the live schema so new store-scoped
      # models are watched without registration. The introspection itself
      # issues queries, so it runs inside `skip` — otherwise the subscriber
      # re-enters this method forever.
      def watched_tables
        @watched_tables ||= skip do
          connection = ActiveRecord::Base.connection
          connection.tables.select do |table|
            table.start_with?('spree_') &&
              !IGNORED_TABLES.include?(table) &&
              connection.column_exists?(table, :store_id)
          end.to_set
        end
      end

      def report(table, sql, name)
        # Bounded window: the interesting frame sits a few levels above the
        # notification subscriber, and materializing a full request backtrace
        # per violation is what makes log mode expensive.
        frames = caller(3, 30) || []
        location = frames.find { |line| !line.include?('/gems/') } || frames.first
        message = "[Spree::StoreScopeGuard] store-less query on #{table} inside a guarded request " \
                  "(#{name}): #{sql.truncate(300)}\n  at #{location}\n" \
                  '  Scope the lookup through current_store, or wrap a deliberately global lookup in Spree::StoreScopeGuard.skip { }.'

        raise UnscopedQueryError, message if mode == 'raise'

        Rails.logger.warn(message)
      end
    end
  end
end
