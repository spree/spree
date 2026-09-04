require 'spec_helper'

RSpec.describe Spree::Customers::Anonymize do
  let(:store) { @default_store }
  let(:customer) { create(:customer, email: 'buyer@example.com', first_name: 'Ada', last_name: 'Lovelace', phone: '+44 20 7946 0958') }

  subject(:result) { described_class.call(customer: customer, store: store) }

  describe 'the account' do
    it 'replaces the identifying fields and keeps the row' do
      result
      customer.reload

      expect(customer.email).to match(/\Aanonymized-[0-9a-f-]+@invalid\z/)
      expect(customer.first_name).to eq('Redacted')
      expect(customer.last_name).to eq('Redacted')
      expect(customer.phone).to be_nil
      expect(customer).to be_persisted
    end

    it 'stamps when the erasure happened' do
      expect { result }.to change { customer.reload.anonymized_at }.from(nil)
    end

    it 'withdraws marketing consent and records why' do
      customer.update!(accepts_email_marketing: true)

      result
      customer.reload

      expect(customer.accepts_email_marketing).to be(false)
      expect(customer.email_marketing_consent_source).to eq('anonymization')
    end

    # Leaving the credential would make the erasure reversible: whoever knew
    # the old password could sign back in, write the name and phone back, and
    # a second erasure would be refused as already done.
    it 'stops the old password working' do
      expect(customer.valid_password?('secret123')).to be(true)

      result

      expect(customer.reload.valid_password?('secret123')).to be(false)
    end

    it 'refuses a customer already anonymized' do
      described_class.call(customer: customer, store: store)

      second = described_class.call(customer: customer.reload, store: store)

      expect(second).to be_failure
    end
  end

  describe 'the address book' do
    let!(:address) { create(:address, owner: customer, first_name: 'Ada', address1: '5 Baker Street', postal_code: '90210', phone: '+1 555 0142') }

    it 'redacts the street line and phone but keeps the jurisdiction' do
      original_country = address.country_code
      original_city = address.city

      result
      address.reload

      expect(address.address1).to eq('Redacted')
      expect(address.first_name).to eq('Redacted')
      expect(address.phone).to be_nil
      expect(address.country_code).to eq(original_country)
      expect(address.city).to eq(original_city)
    end

    it 'truncates the postcode rather than clearing it' do
      result

      expect(address.reload.postal_code).to eq('90')
    end

    it 'soft-deletes the customer\'s own entries' do
      result

      expect(address.reload.deleted_at).to be_present
    end

    it 'reaches an address the customer had already removed' do
      old_address = create(:address, owner: customer, address1: '1 Old Street', first_name: 'Ada')
      old_address.update_columns(deleted_at: 1.day.ago)

      result
      old_address.reload

      expect(old_address.address1).to eq('Redacted')
      expect(old_address.first_name).to eq('Redacted')
    end
  end

  describe 'past orders' do
    let(:order) { create(:completed_order_with_totals, customer: customer, store: store) }

    before do
      order.update_columns(email: 'buyer@example.com', customer_note: 'leave with neighbour', last_ip_address: '203.0.113.4')
    end

    it 'keeps the financial record intact' do
      original_total = order.total
      original_item_total = order.item_total
      line_item_count = order.line_items.count

      result
      order.reload

      expect(order.total).to eq(original_total)
      expect(order.item_total).to eq(original_item_total)
      expect(order.line_items.count).to eq(line_item_count)
      expect(order).to be_persisted
    end

    it 'scrubs the personal data attached to it' do
      result
      order.reload

      expect(order.email).to eq(customer.reload.email)
      expect(order.customer_note).to be_nil
      expect(order.last_ip_address).to be_nil
    end

    it 'redacts the address snapshot but leaves the tax jurisdiction readable' do
      ship_address = order.ship_address
      original_state = ship_address.state_code
      original_country = ship_address.country_code

      result
      ship_address.reload

      expect(ship_address.address1).to eq('Redacted')
      expect(ship_address.last_name).to eq('Redacted')
      expect(ship_address.state_code).to eq(original_state)
      expect(ship_address.country_code).to eq(original_country)
    end

    it 'leaves the snapshot readable rather than deleting it' do
      ship_address_id = order.ship_address_id

      result

      expect(Spree::Address.find_by(id: ship_address_id)).to be_present
    end
  end

  describe 'saved cards' do
    let!(:card) { create(:credit_card, customer: customer, name: 'Ada Lovelace') }

    it 'erases the cardholder name' do
      result

      expect(card.reload.name).to eq('Redacted')
    end

    it 'keeps the card reachable, so a refund on a retained order still has its source' do
      result

      # Spree::Payment#source carries no with_deleted scope, so a soft-deleted
      # card reads back as nil and breaks refunds on orders that were kept.
      expect(card.reload.deleted_at).to be_nil
      expect(Spree::CreditCard.find_by(id: card.id)).to be_present
    end

    it 'keeps the digits a refund is traced by' do
      digits = card.last_digits

      result

      expect(card.reload.last_digits).to eq(digits)
    end
  end

  describe 'credentials and sessions' do
    let!(:refresh_token) do
      Spree::RefreshToken.create!(
        user: customer, token: SecureRandom.hex(16), expires_at: 1.week.from_now,
        audience: 'storefront_api', ip_address: '203.0.113.4', user_agent: 'Mozilla/5.0'
      )
    end

    it 'signs the account out everywhere' do
      expect { result }.to change { Spree::RefreshToken.where(user_id: customer.id).count }.to(0)
    end
  end

  describe 'consent history' do
    let!(:consent) do
      create(:consent_record, store: store, owner: customer, email: 'buyer@example.com', ip_address: '203.0.113.4')
    end

    it 'keeps the proof that consent was given' do
      result

      expect(consent.reload).to be_present
      expect(consent.purpose).to eq(Spree::ConsentRecord::TERMS_OF_SERVICE)
      expect(consent.recorded_at).to be_present
    end

    it 'removes the contact details attached to it' do
      result
      consent.reload

      expect(consent.email).to be_nil
      expect(consent.ip_address).to be_nil
    end
  end

  describe 'an abandoned cart' do
    let!(:cart) do
      create(:cart, customer: customer, store: store).tap do |record|
        record.update_columns(email: 'buyer@example.com', last_ip_address: '203.0.113.4',
                              customer_note: 'ring the bell')
      end
    end

    it 'scrubs the personal data on it' do
      result
      cart.reload

      expect(cart.email).to eq(customer.reload.email)
      expect(cart.last_ip_address).to be_nil
      expect(cart.customer_note).to be_nil
    end
  end

  # A split checkout keeps its own address snapshots on the group, beside the
  # ones on each seller's order.
  describe 'a purchase order the buyer uploaded' do
    let!(:order) do
      create(:completed_order_with_totals, customer: customer, store: store).tap do |placed|
        placed.po_document.attach(
          io: StringIO.new('%PDF-1.4 letterhead with a name and an address'),
          filename: 'po.pdf', content_type: 'application/pdf'
        )
      end
    end

    it 'removes the file, which is the buyer\'s own document' do
      expect(order.po_document).to be_attached

      result

      expect(order.reload.po_document).not_to be_attached
    end
  end

  describe 'a place on a company roster' do
    let!(:membership) { create(:company_membership, customer: customer) }

    it 'gives up the membership, which names the person at a small firm' do
      result

      expect(Spree::CompanyMembership.where(id: membership.id)).to be_empty
    end
  end

  # Deleting a file is not something a rollback can undo.
  describe 'when a later step fails' do
    let!(:order) do
      create(:completed_order_with_totals, customer: customer, store: store).tap do |placed|
        placed.po_document.attach(
          io: StringIO.new('%PDF-1.4 letterhead'),
          filename: 'po.pdf', content_type: 'application/pdf'
        )
      end
    end

    before do
      allow_any_instance_of(described_class).to receive(:remove_newsletter_subscriptions).
        and_raise(ActiveRecord::Rollback)
    end

    it 'leaves the buyer\'s document where it was' do
      described_class.call(customer: customer, store: store) rescue nil

      expect(order.reload.po_document).to be_attached
    end

    it 'leaves the person erasable' do
      described_class.call(customer: customer, store: store) rescue nil

      expect(customer.reload.anonymized_at).to be_nil
    end
  end

  it 'tells subscribers the person is anonymized, not that they still are not' do
    seen = nil
    allow(customer).to receive(:publish_event) do |name, *|
      seen = customer.anonymized_at if name == 'customer.anonymized'
    end

    result

    expect(seen).to be_present
  end

  # A second erasure is refused as already done, so anything written back
  # afterwards would stay with no supported way to remove it.
  describe 'an account that has already been erased' do
    before { result }

    it 'refuses personal data written back onto it' do
      expect(customer.reload.update(first_name: 'Ada', last_name: 'Lovelace')).to be(false)
    end

    it 'still allows the rest of the row to be edited' do
      expect(customer.reload.update(selected_locale: 'fr')).to be(true)
    end
  end

  describe 'a store credit balance' do
    let!(:store_credit) do
      create(:store_credit, customer: customer, store: store).
        tap { |credit| credit.update_columns(memo: 'goodwill after the complaint') }
    end

    it 'keeps the money but clears the note written beside it' do
      result
      store_credit.reload

      expect(store_credit.amount).to be_present
      expect(store_credit.memo).to be_nil
    end
  end

  # A card saved during guest checkout carries no customer, so it is reachable
  # only through the payment on the order it paid for.
  describe 'a card used at guest checkout' do
    let!(:guest_order) do
      create(:completed_order_with_totals, store: store).
        tap { |order| order.update_columns(customer_id: nil, email: 'buyer@example.com') }
    end

    let!(:card) do
      create(:credit_card, name: 'Ada Lovelace').tap do |credit_card|
        credit_card.update_columns(customer_id: nil)
        create(:payment, order: guest_order, source: credit_card)
      end
    end

    # Cards are soft-deleted, so a wallet the person emptied still holds their
    # name. The address book has no such scope, which is why only this path
    # needs to say so.
    it 'redacts a card the person removed from their wallet' do
      removed = create(:credit_card, name: 'Ada Lovelace')
      removed.update_columns(customer_id: customer.id, deleted_at: Time.current)

      result

      expect(removed.reload.name).to eq('Redacted')
    end

    it 'redacts a card charged against a split checkout' do
      group = create(:order_group, store: store, customer: customer)
      split_card = create(:credit_card, name: 'Ada Lovelace')
      split_card.update_columns(customer_id: nil)
      create(:payment, order: nil, order_group: group, source: split_card, amount: 0)

      result

      expect(split_card.reload.name).to eq('Redacted')
    end

    it 'redacts a card left on a checkout that was never finished' do
      cart = create(:cart, customer: customer, store: store)
      abandoned_card = create(:credit_card, name: 'Ada Lovelace')
      abandoned_card.update_columns(customer_id: nil)
      create(:payment, order: nil, cart: cart, source: abandoned_card, amount: 0)

      result

      expect(abandoned_card.reload.name).to eq('Redacted')
    end

    it 'redacts the cardholder name' do
      result

      expect(card.reload.name).to eq('Redacted')
    end
  end

  describe 'a checkout split across sellers' do
    let!(:address) { create(:address, address1: '5 Baker Street', first_name: 'Ada') }
    let!(:order_group) do
      create(:order_group, store: store, customer: customer).tap do |group|
        group.update_columns(bill_address_id: address.id, ship_address_id: address.id)
      end
    end

    it 'clears the merchant notes the group carries' do
      order_group.update_columns(metadata: { 'crm' => 'vip' })

      result

      expect(order_group.reload.metadata).to eq({})
    end

    it 'redacts the addresses the group holds' do
      result

      expect(address.reload.address1).to eq('Redacted')
    end
  end

  describe 'a purchase made as a guest, before the account existed' do
    let!(:guest_order) do
      create(:completed_order_with_totals, store: store).tap do |order|
        order.update_columns(customer_id: nil, email: 'buyer@example.com',
                             last_ip_address: '203.0.113.4')
      end
    end

    it 'scrubs the order, which the account does not own' do
      result
      guest_order.reload

      expect(guest_order.email).to eq(customer.reload.email)
      expect(guest_order.last_ip_address).to be_nil
    end

    it 'redacts the address that came with it' do
      address = guest_order.ship_address

      result

      expect(address.reload.address1).to eq('Redacted')
    end

    it 'leaves another person\'s guest order alone' do
      other = create(:completed_order_with_totals, store: store)
      other.update_columns(customer_id: nil, email: 'someone-else@example.com')

      result

      expect(other.reload.email).to eq('someone-else@example.com')
    end

    # An order keeps the casing the address was typed in, so the same person
    # can be recorded as both `buyer@` and `Buyer@`. Matching exactly would
    # leave the guest checkout holding their name, street and IP address.
    it 'scrubs one placed under a different casing of the same address' do
      shouted = create(:completed_order_with_totals, store: store)
      shouted.update_columns(customer_id: nil, email: 'BUYER@Example.com',
                             last_ip_address: '203.0.113.4')

      result
      shouted.reload

      expect(shouted.email).to eq(customer.reload.email)
      expect(shouted.last_ip_address).to be_nil
    end

    it 'removes a newsletter sign-up stored under a different casing' do
      subscriber = create(:newsletter_subscriber, store: store, email: 'buyer@example.com')
      subscriber.update_columns(customer_id: nil, email: 'Buyer@Example.com')

      result

      expect(Spree::NewsletterSubscriber.where(id: subscriber.id)).to be_empty
    end
  end

  describe 'traces left by guest checkout' do
    let!(:guest_subscriber) do
      create(:newsletter_subscriber, store: store, email: 'buyer@example.com').tap do |record|
        record.update_columns(customer_id: nil)
      end
    end

    let!(:guest_consent) do
      order = create(:completed_order_with_totals, store: store)
      create(:consent_record, store: store, owner: order, email: 'buyer@example.com',
                              ip_address: '203.0.113.4')
    end

    it 'removes a subscription made before the account existed' do
      result

      expect(Spree::NewsletterSubscriber.where(email: 'buyer@example.com')).to be_empty
    end

    it 'scrubs consent recorded against the order rather than the account' do
      result
      guest_consent.reload

      expect(guest_consent.email).to be_nil
      expect(guest_consent.ip_address).to be_nil
    end
  end

  describe 'the marketing consent it withdraws' do
    before { customer.update!(accepts_email_marketing: true) }

    it 'records the withdrawal as a consent event' do
      result

      withdrawal = Spree::ConsentRecord.where(owner: customer).
                   for_purpose(Spree::ConsentRecord::EMAIL_MARKETING).recent_first.first

      expect(withdrawal.accepted).to be(false)
      expect(withdrawal.source).to eq(Spree::ConsentRecord::ANONYMIZATION)
    end

    it 'leaves no contact detail on the row it writes' do
      result

      withdrawal = Spree::ConsentRecord.where(owner: customer).
                   for_purpose(Spree::ConsentRecord::EMAIL_MARKETING).recent_first.first

      expect(withdrawal.email).to be_nil
    end

    it 'writes nothing when there was no consent to withdraw' do
      customer.update!(accepts_email_marketing: false)

      result

      expect(Spree::ConsentRecord.where(owner: customer).
             for_purpose(Spree::ConsentRecord::EMAIL_MARKETING)).to be_empty
    end
  end

  # Each finished export is a complete copy of everything being erased, behind
  # a link that stays live for days. Leaving it would make the erasure a
  # formality.
  describe 'exports produced before the erasure' do
    let(:data_request) { create(:data_request, store: store, customer: customer) }

    before { Spree::DataRequests::Fulfill.call(data_request: data_request) }

    it 'stops being downloadable' do
      expect { result }.to change { data_request.reload.downloadable? }.from(true).to(false)
    end

    it 'drops the token, so a link already emailed stops resolving' do
      result

      expect(data_request.reload.download_token).to be_nil
    end

    it 'keeps the record that the request was answered' do
      result

      expect(data_request.reload).to be_completed
      expect(data_request.requested_at).to be_present
    end
  end

  # The access export discloses all three as this person's data, so leaving
  # them would make the two halves disagree about what the store holds. The
  # schema tripwire cannot catch these: a custom field's value lives in a
  # column called `value`.
  describe 'what the merchant recorded about them' do
    before do
      customer.tag_list = %w[vip complained-twice]
      customer.save!
      create(:wishlist, customer: customer)
    end

    it 'removes the tags staff filed them under' do
      result

      expect(customer.reload.tag_list.to_a).to be_empty
    end

    it 'removes the lists they built' do
      result

      expect(Spree::Wishlist.where(customer_id: customer.id)).to be_empty
    end
  end

  describe 'a tax registration on the account' do
    let!(:identifier) { create(:tax_identifier, owner: customer) }

    # The snapshot frozen onto an order stays, like the address beside it —
    # but the live profile copy has nothing keeping it.
    it 'is removed' do
      result

      expect(Spree::TaxIdentifier.where(id: identifier.id)).to be_empty
    end
  end

  it 'announces the erasure' do
    expect(customer).to receive(:publish_event).with('customer.anonymized', hash_including(:store_id))

    described_class.call(customer: customer, store: store)
  end

  describe 'the veto hook' do
    let(:handler) { ->(workflow) { workflow.reject!('legal hold') } }

    before { Spree.hooks.register('customers.anonymize.validate', handler) }
    after { Spree.hooks.unregister('customers.anonymize.validate', handler) }

    it 'lets a host app refuse the erasure' do
      expect(result).to be_failure
      expect(customer.reload.anonymized_at).to be_nil
      expect(customer.reload.email).to eq('buyer@example.com')
    end
  end
end
