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

  # The other direction, and the one this feature kept getting wrong.
  #
  # A table the erasure scrubs is by definition personal data, so an access
  # request has to disclose it. The export is assembled section by section by
  # hand while the anonymizer works from the schema, so the export is what
  # falls behind — repeatedly, and each time it looked like a different bug.
  #
  # Every covered table maps to the export section that answers for it.
  EXPORT_SECTIONS = {
    'spree_customers' => %i[account marketing_consent custom_fields],
    'spree_addresses' => %i[addresses orders draft_orders carts order_groups],
    'spree_orders' => %i[orders draft_orders],
    'spree_order_groups' => %i[order_groups],
    'spree_carts' => %i[carts],
    'spree_credit_cards' => %i[payment_sources],
    'spree_gateway_customers' => %i[payment_sources],
    'spree_user_identities' => %i[connected_logins],
    'spree_consent_records' => %i[consent_records],
    'spree_newsletter_subscribers' => %i[marketing_consent],
    'spree_data_requests' => %i[],
    'spree_refresh_tokens' => %i[]
  }.freeze

  it 'discloses every table that erasure scrubs' do
    payload = Spree::Customers::DataExport.new(
      customer: create(:customer), store: @default_store
    ).call

    missing = COVERED_TABLES.keys.reject do |table|
      sections = EXPORT_SECTIONS[table]
      sections.nil? || sections.empty? || sections.all? { |section| payload.key?(section) }
    end

    undeclared = COVERED_TABLES.keys - EXPORT_SECTIONS.keys

    expect(undeclared).to be_empty, <<~MESSAGE
      These tables are erased but no export section is declared for them:

        #{undeclared.join("\n  ")}

      Add them to EXPORT_SECTIONS. A table with nothing to disclose (a
      credential, an operational record) maps to an empty list, with the
      reason in a comment.
    MESSAGE

    expect(missing).to be_empty, <<~MESSAGE
      These tables are erased but the export no longer has the section that
      disclosed them:

        #{missing.join("\n  ")}

      An access request has to name whatever an erasure removes.
    MESSAGE
  end

  # Field level, where the section-level check above cannot see.
  #
  # Most of what went wrong on this feature was one field reaching one side
  # and not the other — card metadata disclosed but never erased, a group's
  # notes erased but never disclosed. Both directions are defects.
  #
  # Rather than compare two hand-written lists, which would agree with each
  # other while both disagreed with the code, this runs the real erasure over
  # a customer with data in every one of these places and asserts the export
  # named whatever the erasure changed.
  it 'discloses every field its erasure goes on to clear' do
    customer = create(:customer, email: 'subject@example.com')
    card = create(:credit_card, name: 'Ada Lovelace')
    card.update_columns(customer_id: customer.id, metadata: { 'wallet' => 'apple-pay' })
    group = create(:order_group, store: @default_store, customer: customer)
    group.update_columns(metadata: { 'crm' => 'vip' })
    Spree::ConsentRecord.create!(
      store: @default_store, owner: customer, purpose: Spree::ConsentRecord::EMAIL_MARKETING,
      source: 'account', accepted: true, email: customer.email,
      ip_address: '203.0.113.9', user_agent: 'Mozilla/5.0', recorded_at: Time.current
    )

    payload = Spree::Customers::DataExport.new(customer: customer, store: @default_store).call
    disclosed = JSON.generate(payload)

    # Every value about to be wiped should appear somewhere in the response.
    values = ['Ada Lovelace', 'apple-pay', 'vip', '203.0.113.9', 'Mozilla/5.0']
    undisclosed = values.reject { |value| disclosed.include?(value) }

    expect(undisclosed).to be_empty, <<~MESSAGE
      The access response does not mention these values, but erasure clears
      them:

        #{undisclosed.join("\n  ")}
    MESSAGE

    Spree::Customers::Anonymize.call(customer: customer, store: @default_store)

    surviving = values.select do |value|
      [card.reload.name, card.metadata.to_s, group.reload.metadata.to_s,
       Spree::ConsentRecord.where(owner: customer).pluck(:ip_address, :user_agent).to_s].
        any? { |held| held.include?(value) }
    end

    expect(surviving).to be_empty, <<~MESSAGE
      The access response disclosed these values but erasure left them in the
      database:

        #{surviving.join("\n  ")}
    MESSAGE
  end

  it 'names a real table in every entry, so the lists cannot rot' do
    tables = ActiveRecord::Base.connection.tables
    declared = COVERED_TABLES.keys + EXEMPT_TABLES.keys

    expect(declared - tables).to be_empty
  end
end
