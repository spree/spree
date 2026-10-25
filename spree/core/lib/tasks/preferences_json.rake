# frozen_string_literal: true

# 5.6 → 6.0 follow-ups to the ConvertPreferencesToJson migration
# (docs/plans/6.0-json-preferences.md). Both are idempotent.
module Spree
  module SecretPreferencesUpgrade
    # The models keeping secrets in `secret_preferences`, one per table.
    def self.models
      Rails.application.eager_load!
      Spree::Base.descendants.select do |model|
        model.include?(Spree::SecretPreferences) && model.base_class == model && model.table_exists?
      end
    end

    # Every row of the model, deleted ones included, except rows whose class
    # is no longer installed — loading one of those raises, which would stop
    # the task before it reached the rest. They are reported and left as
    # they are; their secrets stay readable.
    #
    # @return [ActiveRecord::Relation]
    def self.loadable_rows(model)
      rows = model.unscoped
      return rows unless model.column_names.include?(model.inheritance_column)

      types = rows.distinct.pluck(model.inheritance_column)
      missing = types.compact.reject(&:safe_constantize)
      return rows if missing.empty?

      missing.each { |type| puts "  #{model.table_name}: skipped rows of #{type}, which is not installed" }
      rows.where.not(model.inheritance_column => missing).or(rows.where(model.inheritance_column => nil))
    end
  end
end

namespace :spree do
  namespace :upgrade do
    desc <<~DESC
      Converts any preferences row still holding YAML to JSON, and moves secrets
      left in `preferences` to the encrypted `secret_preferences` column.

      The 6.0 migration does both itself, so a normal `db:migrate` leaves nothing
      for this task. It exists for schemas changed out of band, and for secrets of
      a class that was not loaded when the migration ran (an extension gem added
      afterwards).
    DESC
    task preferences_json: :environment do
      conversion = Spree::Preferences::JsonConversion.new(ActiveRecord::Base.connection, log: ->(message) { puts "  #{message}" })

      conversion.preference_tables.each do |table|
        converted = conversion.text_column?(table) ? conversion.convert_text_table(table) : conversion.convert_table(table)
        puts "  #{table}: #{converted} rows converted from YAML" if converted.positive?
      end

      Spree::SecretPreferencesUpgrade.models.each do |model|
        moved = 0

        Spree::SecretPreferencesUpgrade.loadable_rows(model).find_each do |record|
          separated = record.separated_secret_preferences
          next unless separated

          # Written without callbacks: moving a secret is not a change to it, and
          # must not look like one to a gateway that re-registers on key changes.
          record.update_columns(separated)
          moved += 1
        end

        puts "  #{model.table_name}: moved secrets out of preferences for #{moved} rows" if moved.positive?
      end

      puts 'preferences_json done.'
    end

    desc <<~DESC
      Encrypts every `secret_preferences` value still stored in plain text.

      The 6.0 migration moves existing secrets into `secret_preferences` without
      encrypting them, so it never depends on encryption keys. They stay readable
      as they are and are encrypted on their next save; this task encrypts them
      all at once. Skips with a note when Active Record encryption keys are not
      configured.
    DESC
    task encrypt_secret_preferences: :environment do
      unless ActiveRecord::Encryption.config.has_primary_key?
        puts '  Active Record encryption keys are not configured, so secrets stay in plain text. ' \
             'See https://spreecommerce.org/docs/developer/deployment/environment_variables'
        next
      end

      Spree::SecretPreferencesUpgrade.models.each do |model|
        count = 0
        Spree::SecretPreferencesUpgrade.loadable_rows(model).where.not(secret_preferences: nil).find_each do |record|
          record.encrypt
          count += 1
        end
        puts "  #{model.table_name}: encrypted secrets for #{count} rows"
      end

      puts 'encrypt_secret_preferences done.'
    end
  end
end
