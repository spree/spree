# Migration off the legacy spree_avatax_official extension. Gem-owned, because
# core knows nothing about that extension — and every step is guarded, so a
# fresh install runs it as a no-op.
namespace :spree_avalara do
  desc 'Move a store from spree_avatax_official onto spree_avalara (idempotent)'
  task upgrade: :environment do
    SpreeAvalara::Upgrader.new.call
  end

  namespace :upgrade do
    desc 'Drop the legacy spree_avatax_official schema (destructive; run after spree_avalara:upgrade)'
    task drop_legacy_schema: :environment do
      SpreeAvalara::Upgrader.new.drop_legacy_schema!
    end
  end
end

module SpreeAvalara
  # Defined here rather than in app/ so it ships with the task and nothing else
  # can call it by accident.
  class Upgrader
    LEGACY_INTEGRATION_TYPE = 'Spree::Integrations::Avalara'.freeze
    LEGACY_USER_TABLE = 'spree_users'.freeze
    LEGACY_TRANSACTIONS_TABLE = 'spree_avatax_official_transactions'.freeze

    # Prefixes that identify the VAT regime a number belongs to. EL is Greece's
    # VAT prefix and XI is Northern Ireland's, both of which file as EU numbers.
    EU_VAT_PREFIXES = %w[AT BE BG CY CZ DE DK EE EL ES FI FR HR HU IE IT LT LU
                         LV MT NL PL PT RO SE SI SK XI].freeze

    def call
      say 'Upgrading to spree_avalara'
      say "  integrations retyped: #{retype_integrations}"
      say "  tax identifiers created from vat_id: #{migrate_vat_ids}"
      report_preserved_exemption_data
      say "  synthesized tax rates deleted: #{delete_synthesized_tax_rates}"
      say "  markets pointed at Avalara: #{point_markets_at_avalara}"
      say
      say '  Legacy schema is left in place. Once you have checked the result, drop it with:'
      say '    bin/rails spree_avalara:upgrade:drop_legacy_schema'
      say '  A document id is not carried over for orders filed by the legacy extension: it recorded'
      say '  the document code (the order number), which void and refund derive anyway.'
    end

    # Deliberately keeps spree_users.exemption_number, avatax_entity_use_code_id
    # and the entity-use-code table: they are the migration source for whichever
    # answer customer-level exemptions get, and nothing reads them meanwhile.
    def drop_legacy_schema!
      say 'Dropping legacy spree_avatax_official schema'

      if connection.table_exists?(LEGACY_TRANSACTIONS_TABLE)
        connection.drop_table(LEGACY_TRANSACTIONS_TABLE)
        say "  dropped #{LEGACY_TRANSACTIONS_TABLE}"
      end

      %w[spree_line_items spree_shipments spree_fulfillments].each do |table|
        next unless connection.table_exists?(table) && connection.column_exists?(table, :avatax_uuid)

        connection.remove_column(table, :avatax_uuid)
        say "  dropped #{table}.avatax_uuid"
      end

      drop_column(LEGACY_USER_TABLE, :vat_id)
      drop_column('spree_stores', :avatax_company_code)

      say '  Kept: exemption_number, avatax_entity_use_code_id and the entity use code table.'
    end

    private

    def retype_integrations
      return 0 unless connection.table_exists?(Spree::Integration.table_name)

      Spree::Integration.where(type: LEGACY_INTEGRATION_TYPE).update_all(type: 'SpreeAvalara::Integration')
    end

    # The legacy extension stored one VAT number per user; core stores a typed
    # registration per owner. Kind comes from the number itself where it says so,
    # then from where the customer is, and eu_vat last — a wrong kind is a failed
    # validation later, not a wrong tax charge.
    def migrate_vat_ids
      source = legacy_vat_id_source
      return 0 if source.nil?

      migrated = 0
      rejected = []

      source.where.not(vat_id: [nil, '']).find_each do |row|
        customer = Spree.customer_class.find_by(id: row.id)
        next if customer.nil?

        kind = vat_kind_for(row.vat_id, customer)
        next if customer.tax_identifiers.exists?(kind: kind)

        identifier = customer.tax_identifiers.new(kind: kind, value: row.vat_id.to_s.strip)

        # The legacy column was free text, so some values will not validate as
        # the registration they claim to be. One of those must not abort the
        # upgrade: a missing identifier means the buyer is charged as a consumer,
        # which is the safe direction, and the merchant can reconcile the list.
        if identifier.save
          migrated += 1
        else
          rejected << "customer #{customer.id}: #{row.vat_id.inspect} (#{identifier.errors.full_messages.to_sentence})"
        end
      end

      report_rejected_vat_ids(rejected)

      migrated
    end

    def report_rejected_vat_ids(rejected)
      return if rejected.empty?

      say "  ! #{rejected.size} vat_id value(s) did not validate and were left behind:"
      rejected.each { |line| say "      #{line}" }
    end

    def vat_kind_for(value, customer)
      number = value.to_s.strip.upcase
      return 'gb_vat' if number.start_with?('GB')
      return 'ch_vat' if number.start_with?('CHE')
      return 'eu_vat' if EU_VAT_PREFIXES.any? { |prefix| number.start_with?(prefix) }

      country = customer_country(customer)
      return 'gb_vat' if country == 'GB'
      return 'ch_vat' if country == 'CH'
      return 'eu_vat' if EU_VAT_PREFIXES.include?(country)

      say "  ! #{value.inspect} names no VAT regime and customer #{customer.id} none either — filed as eu_vat"
      'eu_vat'
    end

    def customer_country(customer)
      address = %i[default_bill_address bill_address default_address].filter_map do |reader|
        customer.public_send(reader) if customer.respond_to?(reader)
      end.first

      address&.country_code.to_s.upcase.presence
    end

    def report_preserved_exemption_data
      source = legacy_user_table
      return if source.nil?

      columns = source.column_names & %w[exemption_number avatax_entity_use_code_id]
      return if columns.empty?

      carrying = source.where(columns.map { |column| "#{column} IS NOT NULL" }.join(' OR ')).count
      return if carrying.zero?

      say "  #{carrying} legacy user(s) carry exemption data (#{columns.join(', ')}), left untouched"
      say '    Company certificates migrate through core; individual exemptions have no home yet.'
    end

    # The legacy extension synthesized a rate row to hang its adjustments on.
    # Left behind, the Internal engine would read it as real configuration.
    def delete_synthesized_tax_rates
      name = ENV.fetch('AVATAX_TAX_RATE_NAME', 'AvaTax Official Tax Rate')

      Spree::TaxRate.where(name: name).destroy_all.size
    end

    # Only where nothing is set. The legacy extension was store-global, so a
    # blank market on an upgrading merchant means "was calculating through
    # Avalara" — and leaving it blank falls back to Internal, whose rate table is
    # empty for exactly these merchants. An explicit choice is never rewritten.
    def point_markets_at_avalara
      pointed = 0

      Spree::Market.where(tax_provider: [nil, '']).find_each do |market|
        next if SpreeAvalara::Integration.active_for(market.store).nil?

        market.update_column(:tax_provider, 'SpreeAvalara::TaxProvider')
        say "  #{market.name} now calculates through Avalara"
        pointed += 1
      end

      pointed
    end

    # An anonymous reader: the legacy table has no model in 6.0, and the column
    # may sit on either the legacy user table or the customer table depending on
    # whether the host copied or renamed.
    def legacy_vat_id_source
      [legacy_user_table, Spree.customer_class].compact.find do |model|
        model.column_names.include?('vat_id')
      end
    end

    def legacy_user_table
      return @legacy_user_table if defined?(@legacy_user_table)

      @legacy_user_table = if connection.table_exists?(LEGACY_USER_TABLE)
                             Class.new(ActiveRecord::Base) { self.table_name = LEGACY_USER_TABLE }
                           end
    end

    def drop_column(table, column)
      return unless connection.table_exists?(table) && connection.column_exists?(table, column)

      connection.remove_column(table, column)
      say "  dropped #{table}.#{column}"
    end

    def connection
      ActiveRecord::Base.connection
    end

    def say(message = '')
      puts message
    end
  end
end
