class ConvertPreferencesToJson < ActiveRecord::Migration[8.1]
  # The tables whose classes declare `:password` preferences. Their secrets move
  # to an encrypted `secret_preferences` column (see Spree::SecretPreferences).
  SECRET_TABLES = %i[spree_payment_methods spree_integrations].freeze

  # Records which tables had their `text` column replaced, so `down` restores
  # `text` only there — a table whose column was already JSON (delivery method
  # rules, commission rules) keeps it. Dropped on the way back down.
  CONVERTED_TABLES_REGISTRY = :spree_converted_preference_tables

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

    create_table CONVERTED_TABLES_REGISTRY, if_not_exists: true do |t|
      t.string :table_name, null: false
    end

    conversion.preference_tables.each do |table|
      if conversion.text_column?(table)
        conversion.convert_text_table(table)
        execute(Arel::InsertManager.new.tap do |insert|
          registry = Arel::Table.new(CONVERTED_TABLES_REGISTRY)
          insert.into(registry).insert([[registry[:table_name], table]])
        end.to_sql)
      else
        conversion.convert_table(table)
      end
    end

    drop_table :spree_preferences, if_exists: true
  end

  # Restores YAML: a `text` column where `up` replaced one, and a YAML document
  # inside a JSON string where the column was already JSON, as before the
  # upgrade. Secrets go back into `preferences` — decrypted, so rolling back an
  # encrypted secret needs the encryption keys — tiers become a hash keyed by
  # threshold again, and decimals return as BigDecimal for every row whose class
  # can be resolved; anything else comes back as the string JSON held.
  def down
    restore = Restore.new(connection, conversion)
    create_table :spree_preferences, if_not_exists: true do |t|
      t.text :value
      t.string :key
      t.timestamps
      t.index :key, unique: true
    end

    converted = converted_tables
    conversion.preference_tables.each do |table|
      if converted.include?(table)
        add_column table, :preferences_yaml, :text
        restore.table(table, target: 'preferences_yaml')
        remove_column table, :preferences
        rename_column table, :preferences_yaml, :preferences
      else
        restore.table(table, target: 'preferences', inside_json: true)
      end
    end

    drop_table CONVERTED_TABLES_REGISTRY, if_exists: true

    SECRET_TABLES.each do |table|
      remove_column table, :secret_preferences if table_exists?(table) && column_exists?(table, :secret_preferences)
    end
  end

  private

  def converted_tables
    return [] unless table_exists?(CONVERTED_TABLES_REGISTRY)

    registry = Arel::Table.new(CONVERTED_TABLES_REGISTRY)
    connection.select_values(registry.project(registry[:table_name]))
  end

  def conversion
    @conversion ||= Spree::Preferences::JsonConversion.new(connection, log: ->(message) { say(message, true) })
  end

  class Restore
    def initialize(connection, conversion)
      @connection = connection
      @conversion = conversion
    end

    def table(table, target:, inside_json: false)
      typed = connection.column_exists?(table, :type)
      secrets = connection.column_exists?(table, :secret_preferences)
      columns = ['id', 'preferences', ('type' if typed), ('secret_preferences' if secrets)].compact

      arel_table = Arel::Table.new(table)
      connection.select_all(arel_table.project(*columns.map { |column| arel_table[column] })).each do |row|
        next if row['preferences'].nil? && row['secret_preferences'].nil?

        preferences = decode(row['preferences']) || {}
        preferences.merge!(decode(decrypt(row['secret_preferences'])) || {}) if secrets
        model = typed ? conversion.model_for(row['type']) : nil
        restore_tiers(preferences, model)
        restore_typed_values(preferences, model)

        yaml = YAML.dump(preferences.transform_keys(&:to_sym))
        conversion.write(table, row['id'], target => inside_json ? JSON.generate(yaml) : yaml)
      end
    end

    private

    attr_reader :connection, :conversion

    def decode(raw)
      raw.is_a?(String) ? JSON.parse(raw) : raw
    end

    # A value written before encryption was enabled is plain JSON and comes
    # back as it is. An encrypted one that cannot be decrypted stops the
    # rollback: writing its ciphertext into `preferences` would replace a
    # gateway's keys with garbage.
    def decrypt(raw)
      return raw if raw.nil? || !encrypted?(raw)

      unless ActiveRecord::Encryption.config.has_primary_key?
        raise ActiveRecord::IrreversibleMigration, 'Encrypted secret_preferences cannot be rolled back without the Active Record encryption keys. Configure them and run the rollback again.'
      end

      ActiveRecord::Encryption.encryptor.decrypt(raw)
    rescue ActiveRecord::Encryption::Errors::Decryption
      raise ActiveRecord::IrreversibleMigration, 'An encrypted secret_preferences value could not be decrypted with the configured keys. Restore the keys it was encrypted with and run the rollback again.'
    end

    def encrypted?(raw)
      parsed = JSON.parse(raw)
      parsed.is_a?(Hash) && parsed.key?('p') && parsed.key?('h')
    rescue JSON::ParserError
      false
    end

    def restore_tiers(preferences, model)
      tiers = preferences['tiers']
      return unless tiers.is_a?(Array) && Spree::Preferences::JsonConversion.tiered_calculator?(model)

      # A value that is not a number is kept as written, so two such tiers
      # cannot collapse into one nil key.
      preferences['tiers'] = tiers.to_h do |tier|
        [Spree::Calculator::Tiers.decimal(tier['threshold']) || tier['threshold'],
         Spree::Calculator::Tiers.decimal(tier['value']) || tier['value']]
      end
    end

    def restore_typed_values(preferences, model)
      return unless model.respond_to?(:declared_preference_types)

      model.declared_preference_types.each do |name, type|
        preferences[name.to_s] = Spree::Preferences::Preferable.restore_value(preferences[name.to_s], type) if preferences.key?(name.to_s)
      end
    end
  end
end
