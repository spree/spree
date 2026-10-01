class ConvertPreferencesToJson < ActiveRecord::Migration[8.1]
  # The tables whose classes declare `:password` preferences. Their secrets move
  # to an encrypted `secret_preferences` column (see Spree::SecretPreferences).
  SECRET_TABLES = %i[spree_payment_methods spree_integrations].freeze

  # The conversion lives here rather than in the upgrade rake task because the
  # manifest runs AFTER db:migrate — a task scheduled there would find the YAML
  # column already replaced. Secrets are moved in plain text, so this needs no
  # encryption keys; they stay readable and `spree:upgrade:encrypt_secret_preferences`
  # encrypts them.
  def up
    SECRET_TABLES.each do |table|
      next unless table_exists?(table)

      add_column table, :secret_preferences, :text unless column_exists?(table, :secret_preferences)
    end

    conversion.preference_tables.each do |table|
      if conversion.text_column?(table)
        conversion.convert_text_table(table)
      else
        conversion.convert_table(table)
      end
    end

    if table_exists?(:spree_preferences) && column_exists?(:spree_preferences, :value, :text)
      add_json_column :spree_preferences, :value_json
      conversion.convert_values('spree_preferences', source: 'value', target: 'value_json')
      remove_column :spree_preferences, :value
      rename_column :spree_preferences, :value_json, :value
    end
  end

  # Restores YAML text columns. Secrets go back into `preferences` (decrypted
  # when encryption keys are available), tiers become a hash keyed by threshold
  # again, and decimals return as BigDecimal for every row whose class can be
  # resolved; anything else comes back as the string JSON held.
  def down
    restore = Restore.new(connection, conversion)

    if table_exists?(:spree_preferences) && column_exists?(:spree_preferences, :value)
      add_column :spree_preferences, :value_yaml, :text
      restore.values('spree_preferences', source: 'value', target: 'value_yaml')
      remove_column :spree_preferences, :value
      rename_column :spree_preferences, :value_yaml, :value
    end

    conversion.preference_tables.each do |table|
      add_column table, :preferences_yaml, :text
      restore.table(table, target: 'preferences_yaml')
      remove_column table, :preferences
      rename_column table, :preferences_yaml, :preferences
    end

    SECRET_TABLES.each do |table|
      remove_column table, :secret_preferences if table_exists?(table) && column_exists?(table, :secret_preferences)
    end
  end

  private

  def conversion
    @conversion ||= Spree::Preferences::JsonConversion.new(connection, log: ->(message) { say(message, true) })
  end

  def add_json_column(table, column)
    change_table table do |t|
      if t.respond_to?(:jsonb)
        t.jsonb column
      else
        t.json column
      end
    end
  end

  class Restore
    def initialize(connection, conversion)
      @connection = connection
      @conversion = conversion
    end

    def table(table, target:)
      typed = connection.column_exists?(table, :type)
      secrets = connection.column_exists?(table, :secret_preferences)
      columns = ['id', 'preferences', ('type' if typed), ('secret_preferences' if secrets)].compact

      connection.select_all("SELECT #{columns.map { |c| connection.quote_column_name(c) }.join(', ')} FROM #{connection.quote_table_name(table)}").each do |row|
        next if row['preferences'].nil? && row['secret_preferences'].nil?

        preferences = decode(row['preferences']) || {}
        preferences.merge!(decode(decrypt(row['secret_preferences'])) || {}) if secrets
        model = typed ? conversion.model_for(row['type']) : nil
        restore_tiers(preferences, model)
        restore_decimals(preferences, model)

        conversion.write(table, row['id'], target => YAML.dump(preferences.transform_keys(&:to_sym)))
      end
    end

    def values(table, source:, target:)
      connection.select_all("SELECT id, #{connection.quote_column_name(source)} FROM #{connection.quote_table_name(table)}").each do |row|
        next if row[source].nil?

        conversion.write(table, row['id'], target => YAML.dump(decode(row[source])))
      end
    end

    private

    attr_reader :connection, :conversion

    def decode(raw)
      raw.is_a?(String) ? JSON.parse(raw) : raw
    end

    def decrypt(raw)
      return raw if raw.nil? || !ActiveRecord::Encryption.config.has_primary_key?

      ActiveRecord::Encryption.encryptor.decrypt(raw)
    rescue ActiveRecord::Encryption::Errors::Base
      raw
    end

    def restore_tiers(preferences, model)
      tiers = preferences['tiers']
      return unless tiers.is_a?(Array) && Spree::Preferences::JsonConversion.tiered_calculator?(model)

      preferences['tiers'] = tiers.to_h { |tier| [BigDecimal(tier['threshold'].to_s, exception: false), BigDecimal(tier['value'].to_s, exception: false)] }
    end

    def restore_decimals(preferences, model)
      return unless model.respond_to?(:declared_preference_types)

      model.declared_preference_types.each do |name, type|
        value = preferences[name.to_s]
        preferences[name.to_s] = BigDecimal(value, exception: false) || value if type == :decimal && value.is_a?(String)
      end
    end
  end
end
