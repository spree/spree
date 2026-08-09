# Defined here rather than in lib/spree/stripe/ — this is a one-release upgrade
# step that dies with the legacy tables, not engine infrastructure.
module SpreeStripe
  # Copies Stripe webhook signing secrets out of the legacy
  # spree_stripe_webhook_keys tables onto the gateway's own preferences.
  #
  # Before 6.0 a signing secret was a row joined to payment methods
  # many-to-many, because a payment method could be shared across stores. A
  # payment method now belongs to exactly one store, so there is a single
  # endpoint per gateway and the secret is just another gateway preference.
  #
  # Reads the legacy tables through throwaway model classes — the legacy models
  # are gone in 6.0. The secret columns were written with deterministic Active
  # Record encryption, so the reader declares it too; installs that never
  # configured encryption keys stored them in plaintext and are read as-is.
  #
  # Idempotent: gateways that already hold a signing secret are skipped, and the
  # legacy tables are left in place as a rollback path.
  class WebhookKeysMigrator
    LEGACY_KEYS_TABLE = 'spree_stripe_webhook_keys'.freeze
    LEGACY_JOIN_TABLE = 'spree_stripe_payment_methods_webhook_keys'.freeze

    # @return [Hash, nil] counts, or nil when the legacy tables are absent
    def call
      return nil unless connection.table_exists?(LEGACY_KEYS_TABLE) && connection.table_exists?(LEGACY_JOIN_TABLE)

      migrated = 0
      skipped = 0
      failed = []

      SpreeStripe::Gateway.with_deleted.find_each do |gateway|
        if gateway.preferred_webhook_signing_secret.present?
          skipped += 1
          next
        end

        key = legacy_key_for(gateway)
        if key.blank?
          skipped += 1
          next
        end

        gateway.update_columns(
          preferences: gateway.preferences.merge(
            webhook_endpoint_id: key.stripe_id,
            webhook_signing_secret: key.signing_secret
          ),
          updated_at: Time.current
        )
        migrated += 1
      rescue StandardError => e
        failed << { gateway_id: gateway.id, error: e.message }
      end

      { migrated: migrated, skipped: skipped, failed: failed }
    end

    private

    def connection
      ActiveRecord::Base.connection
    end

    # A payment method could be joined to several keys historically; the most
    # recent one is the endpoint Stripe would be signing with today.
    def legacy_key_for(gateway)
      key_ids = join_model.where(payment_method_id: gateway.id).order(:created_at).pluck(:webhook_key_id)
      return if key_ids.empty?

      key_model.where(id: key_ids).order(:created_at).last
    end

    def key_model
      @key_model ||= Class.new(ActiveRecord::Base) do
        self.table_name = LEGACY_KEYS_TABLE
        self.inheritance_column = nil

        if Rails.configuration.active_record.encryption.include?(:primary_key)
          encrypts :stripe_id, deterministic: true
          encrypts :signing_secret, deterministic: true
        end
      end
    end

    def join_model
      @join_model ||= Class.new(ActiveRecord::Base) do
        self.table_name = LEGACY_JOIN_TABLE
        self.inheritance_column = nil
      end
    end
  end
end

namespace :spree do
  namespace :upgrade do
    desc <<~DESC
      Moves Stripe webhook signing secrets from the legacy
      spree_stripe_webhook_keys tables onto each gateway's preferences.

      Run once after upgrading to Spree 6.0. Without it, gateways carrying a
      pre-6.0 endpoint have no signing secret and reject incoming webhooks
      until a new endpoint is registered.

      Idempotent. The legacy tables are left in place as a rollback path and
      are dropped in 6.1.
    DESC
    task migrate_stripe_webhook_keys: :environment do
      result = SpreeStripe::WebhookKeysMigrator.new.call

      if result.nil?
        puts 'Legacy Stripe webhook key tables not found — nothing to migrate.'
        next
      end

      puts "Migrated #{result[:migrated]} signing secret(s), skipped #{result[:skipped]}."

      next if result[:failed].empty?

      puts "Failed for #{result[:failed].size} gateway(s):"
      result[:failed].each { |failure| puts "  gateway #{failure[:gateway_id]}: #{failure[:error]}" }
      abort 'Some gateways could not be migrated. Re-run after resolving the errors above.'
    end
  end
end
