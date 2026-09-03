require 'spec_helper'

# A tripwire, not a unit test.
#
# Erasure is only as complete as the list of places personal data lives, and
# that list grows every time someone adds a column. This spec fails when a
# table gains a PII-shaped column that Spree::Customers::Anonymize does not
# reach, so the erasure path is extended in the same change rather than
# quietly falling behind the schema.
#
# Adding a column here without handling it is how a store silently becomes
# non-compliant: nothing else in the suite would notice.
RSpec.describe 'personal data coverage' do
  # Column names that carry data identifying a person. Deliberately wider than
  # contact details: a street line, a postcode and a free-text note all point
  # at a household, and a guard that only caught columns called "email" would
  # pass a new table holding somebody's address.
  PII_COLUMN_PATTERNS = [
    /\Aemail\z/, /_email\z/,
    /\Aphone\z/, /_phone\z/,
    /\Afirst_?name\z/, /\Alast_?name\z/, /\Afull_name\z/,
    /\Aip_address\z/, /_ip_address\z/,
    /\Auser_agent\z/,
    /\Aaddress\d?\z/, /\Apostal_code\z/,
    /\Anote\z/, /_note\z/
  ].freeze

  # Tables whose personal data the anonymizer handles, each with why.
  COVERED_TABLES = {
    'spree_customers' => 'the account itself — anonymize_account',
    'spree_addresses' => 'address book and order snapshots — anonymize_address_book / anonymize_order_addresses',
    'spree_orders' => 'anonymize_purchases',
    'spree_order_groups' => 'anonymize_purchases',
    'spree_credit_cards' => 'anonymize_payment_sources',
    'spree_gateway_customers' => 'anonymize_payment_sources — profiles released at the gateway',
    'spree_user_identities' => 'anonymize_identities',
    'spree_refresh_tokens' => 'anonymize_sessions',
    'spree_consent_records' => 'anonymize_consent_records',
    'spree_newsletter_subscribers' => 'remove_newsletter_subscriptions',
    'spree_data_requests' => 'anonymize_data_requests — the record survives, the address on it does not',
    'spree_carts' => 'anonymize_purchases — carts are their own table since the Cart/Order split'
  }.freeze

  # Tables holding personal data that is deliberately NOT erased by a customer
  # erasure request, each with the reason it survives.
  EXEMPT_TABLES = {
    'spree_admin_users' => 'staff accounts, not data subjects of a customer request',
    'spree_users' => 'the legacy pre-6.0 table; live accounts are spree_customers',
    'spree_invitations' => 'staff invitations — an admin lifecycle, not a customer one',
    'spree_company_invitations' => 'B2B invitations, erased with the company rather than the buyer',
    'spree_stock_locations' => 'a warehouse contact number, not a customer',
    'spree_webhook_deliveries' => 'operational log with its own retention; payloads expire on their own schedule',
    'spree_seller_requirement_submissions' => 'seller onboarding evidence, not customer data',
    'spree_sellers' => 'marketplace seller contact details, not a shopper',
    'spree_stores' => 'the merchant\'s own support and notification addresses',
    'spree_store_translations' => 'translated copies of the merchant\'s own addresses',
    'spree_product_submissions' => 'an operator\'s note about a seller\'s product, not about a shopper'
  }.freeze

  it 'handles every table that stores personal data' do
    uncovered = ActiveRecord::Base.connection.tables.filter_map do |table|
      next if COVERED_TABLES.key?(table) || EXEMPT_TABLES.key?(table)
      next unless table.start_with?('spree_')

      columns = ActiveRecord::Base.connection.columns(table).map(&:name)
      matched = columns.select { |column| PII_COLUMN_PATTERNS.any? { |pattern| column.match?(pattern) } }

      "#{table} (#{matched.join(', ')})" if matched.any?
    end

    expect(uncovered).to be_empty, <<~MESSAGE
      These tables carry personal data that customer erasure does not reach:

        #{uncovered.join("\n  ")}

      Extend Spree::Customers::Anonymize to cover them, then add them to
      COVERED_TABLES. If the data is deliberately retained through an erasure
      request, add the table to EXEMPT_TABLES with the reason.
    MESSAGE
  end

  it 'names a real table in every entry, so the lists cannot rot' do
    tables = ActiveRecord::Base.connection.tables
    declared = COVERED_TABLES.keys + EXEMPT_TABLES.keys

    expect(declared - tables).to be_empty
  end
end
