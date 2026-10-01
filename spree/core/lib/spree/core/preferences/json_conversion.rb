require 'spree/core/preferences/json_coder'

module Spree
  module Preferences
    # Converts preferences stored as YAML to JSON, for the 6.0 migration and the
    # `spree:upgrade:preferences_json` safety net.
    #
    # Rows are read and written through the connection, never through models:
    # a model would load the column through whichever coder the current code
    # declares, which is the thing being converted. The only thing asked of a
    # model class is which of its preferences are secrets, from its
    # declarations alone.
    class JsonConversion
      PERMITTED_CLASSES = [
        Symbol, BigDecimal, Date, Time,
        ActiveSupport::TimeWithZone, ActiveSupport::TimeZone, ActiveSupport::HashWithIndifferentAccess
      ].freeze

      # Tiers move from a hash keyed by threshold to a list of objects, because
      # a JSON object key is always a string.
      TIERED_CALCULATORS = %w[Spree::Calculator::TieredPercent Spree::Calculator::TieredFlatRate].freeze

      class UnreadableRowError < StandardError; end

      # Whether a row's class is a tiered calculator, or an application's
      # subclass of one.
      #
      # @param model [Class, nil] the class the row's `type` names
      # @return [Boolean]
      def self.tiered_calculator?(model)
        model.is_a?(Class) && TIERED_CALCULATORS.any? { |name| model <= name.constantize }
      end

      # @param connection [ActiveRecord::ConnectionAdapters::AbstractAdapter]
      # @param log [#call, nil] receives a line for each row left as it was
      def initialize(connection, log: nil)
        @connection = connection
        @log = log || ->(_message) {}
        @models = Hash.new { |models, type| models[type] = type.presence&.safe_constantize }
      end

      # Resolves a row's `type`, once per type for the life of the conversion.
      #
      # @param type [String, nil]
      # @return [Class, nil]
      def model_for(type)
        @models[type]
      end

      # @param table [String]
      # @param id [Object] the row's primary key
      # @param assignments [Hash{String => String}] column names and the values to write
      def write(table, id, assignments)
        arel_table = Arel::Table.new(table)
        update = Arel::UpdateManager.new(arel_table).
                 set(assignments.map { |column, value| [arel_table[column], value] }).
                 where(arel_table[:id].eq(id))
        connection.update(update)
      end

      # Tables with a `preferences` column that a model storing Spree
      # preferences reads — Spree's, an extension's, or the application's own.
      # A table another library owns is left alone.
      #
      # @return [Array<String>]
      def preference_tables
        Rails.application.eager_load! if defined?(Rails.application) && Rails.application
        owned = ActiveRecord::Base.descendants.filter_map do |model|
          model.table_name if !model.abstract_class? && model.include?(Spree::Preferences::Preferable) && model.table_name
        end

        connection.tables.select { |table| owned.include?(table) && connection.column_exists?(table, :preferences) }.sort
      end

      # Whether the table's `preferences` column is still `text` and needs a
      # JSON column in its place.
      #
      # @param table [String]
      # @return [Boolean]
      def text_column?(table)
        connection.columns(table).find { |column| column.name == 'preferences' }&.type == :text
      end

      # Replaces a `text` preferences column with a JSON one (`jsonb` where the
      # adapter has it), converting every row on the way.
      #
      # @param table [String]
      # @return [Integer] the number of rows written
      def convert_text_table(table)
        type = connection.native_database_types.key?(:jsonb) ? :jsonb : :json
        connection.add_column(table, :preferences_json, type)
        converted = convert_table(table, target: 'preferences_json')
        connection.remove_column(table, :preferences)
        connection.rename_column(table, :preferences_json, :preferences)
        converted
      end

      # Converts every row of `table` whose `source` column holds YAML (as text,
      # or wrapped in a JSON string) and writes the JSON to `target`. Secrets
      # move to `secret_preferences` when the table has that column, and tier
      # ladders change shape.
      #
      # @param table [String]
      # @param source [String] the column to read
      # @param target [String] the column to write, the same one for an in-place conversion
      # @return [Integer] the number of rows written
      def convert_table(table, source: 'preferences', target: 'preferences')
        typed = connection.column_exists?(table, :type)
        secrets_column = connection.column_exists?(table, :secret_preferences)
        rows = rows_with(table, source, ['id', source, ('type' if typed)].compact)

        rows.count do |row|
          preferences, already_json = read(row[source], table, row['id'])
          next false if already_json && source == target

          type = row['type'] if typed
          reshape_tiers(preferences, model_for(type))
          secrets = secrets_column ? extract_secrets(preferences, type, table, row['id']) : {}

          assignments = { target => JSON.generate(preferences) }
          assignments['secret_preferences'] = JSON.generate(secrets) if secrets.any?
          write(table, row['id'], assignments)
          true
        end
      end

      # Converts a column of arbitrary YAML values (not only hashes) into a JSON
      # column — `spree_preferences.value`.
      #
      # @return [Integer] the number of rows written
      def convert_values(table, source:, target:)
        rows = rows_with(table, source, ['id', source])

        rows.count do |row|
          value = parse_yaml(row[source], table, row['id'])
          write(table, row['id'], target => JSON.generate(value.as_json))
          true
        end
      end

      private

      attr_reader :connection, :log

      # @return [Array(Hash, Boolean)] the preferences, and whether they were already JSON
      def read(raw, table, id)
        decoded = raw.is_a?(String) ? decode_json(raw) : raw
        return [decoded.to_h, true] if decoded.is_a?(Hash)

        yaml = decoded.is_a?(String) ? decoded : raw
        value = parse_yaml(yaml, table, id) || {}
        raise UnreadableRowError, "#{table} row #{id}: preferences are not a hash" unless value.is_a?(Hash)

        [JsonCoder.dump(value), false]
      end

      def decode_json(raw)
        JSON.parse(raw)
      rescue JSON::ParserError
        nil
      end

      def parse_yaml(text, table, id)
        YAML.safe_load(text.to_s, permitted_classes: PERMITTED_CLASSES, aliases: true)
      rescue Psych::Exception => e
        raise UnreadableRowError, "#{table} row #{id}: #{e.message}. Fix or clear this row, then run the migration again."
      end

      def reshape_tiers(preferences, model)
        tiers = preferences['tiers']
        return unless tiers.is_a?(Hash) && self.class.tiered_calculator?(model)

        preferences['tiers'] = tiers.map { |threshold, value| { 'threshold' => threshold.to_s, 'value' => value.to_s } }.
                               sort_by { |tier| BigDecimal(tier['threshold'], exception: false) || 0 }
      end

      def extract_secrets(preferences, type, table, id)
        model = model_for(type)
        unless model.respond_to?(:secret_preference_names)
          log.call("#{table} row #{id}: class #{type.inspect} is not loaded, so its secrets stay in preferences until it is")
          return {}
        end

        names = model.secret_preference_names.map(&:to_s)
        secrets = preferences.slice(*names)
        names.each { |name| preferences.delete(name) }
        secrets
      end

      # The given columns of every row whose `present` column is not NULL.
      def rows_with(table, present, columns)
        arel_table = Arel::Table.new(table)
        connection.select_all(arel_table.project(*columns.map { |column| arel_table[column] }).where(arel_table[present].not_eq(nil)))
      end
    end
  end
end
