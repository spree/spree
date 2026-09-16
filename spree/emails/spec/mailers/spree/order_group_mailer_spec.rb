require 'spec_helper'
require 'email_spec'

describe Spree::OrderGroupMailer, type: :mailer do
  include EmailSpec::Helpers
  include EmailSpec::Matchers

  let!(:store) { @default_store }
  let(:group) do
    create(:order_group, :with_parcels, store: store, sellers_count: 2, email: 'buyer@example.com')
  end

  def parts_of(message)
    [message.html_part.body.to_s, message.text_part.body.to_s]
  end

  describe '#confirm_email' do
    it 'goes to the address the purchase was made with' do
      expect(described_class.confirm_email(group).to).to eq(['buyer@example.com'])
    end

    # The number the customer saw at checkout. A child's number (R1001-1) is
    # one seller's share of it, and quoting that is how the old email managed
    # to describe a fraction of the purchase.
    it 'names the purchase, not one of its orders' do
      message = described_class.confirm_email(group)

      expect(message.subject).to include("##{group.number}")
      expect(message.subject).not_to include("##{group.number}-1")
    end

    it 'lists every item the customer bought' do
      parts_of(described_class.confirm_email(group)).each do |body|
        group.line_items.each { |line_item| expect(body).to include(line_item.name) }
      end
    end

    it 'states the total actually paid' do
      parts_of(described_class.confirm_email(group)).each do |body|
        expect(body).to include(group.display_total.to_s)
      end
    end

    it 'names who sold what' do
      parts_of(described_class.confirm_email(group)).each do |body|
        group.sellers.each { |seller| expect(body).to include(seller.name) }
      end
    end

    it 'accepts an id as readily as the record' do
      expect(Spree::OrderGroup).to receive(:find).with(group.id).and_return(group)

      described_class.confirm_email(group.id).message
    end

    it 'prefixes a re-send so the customer knows it is not a second purchase' do
      expect(described_class.confirm_email(group, true).subject).to include('[RESEND]')
    end

    # BaseMailer#current_store memoizes off @order, which a group never sets —
    # left to the fallback this would be the default store's branding.
    it 'is sent by the store the purchase was made in' do
      other_store = create(:store, name: 'Second Store', url: 'other.example.com')
      other_group = create(:order_group, :with_parcels, store: other_store, sellers_count: 2)

      expect(described_class.confirm_email(other_group).subject).to start_with('Second Store')
    end

    describe 'the deliveries it promises' do
      it 'describes one per parcel when sellers ship their own goods' do
        parts_of(described_class.confirm_email(group)).each do |body|
          expect(body).to include('Delivery 1 of 2')
          expect(body).to include('Delivery 2 of 2')
        end
      end

      it 'says how many to expect' do
        expect(described_class.confirm_email(group).text_part.body.to_s).
          to include('arriving in 2 separate deliveries')
      end

      # Several sellers out of one warehouse is one box. Counting orders here
      # would promise deliveries that never arrive.
      it 'describes one delivery when the split merely divided a parcel' do
        shared = create(:order_group, :with_parcels, store: store, sellers_count: 3,
                                                     shared_stock_location: true)

        parts_of(described_class.confirm_email(shared)).each do |body|
          expect(body).to include('Delivery')
          expect(body).not_to include('Delivery 1 of')
        end
      end

      it 'does not promise separate deliveries for a single parcel' do
        shared = create(:order_group, :with_parcels, store: store, sellers_count: 2,
                                                     shared_stock_location: true)

        expect(described_class.confirm_email(shared).text_part.body.to_s).
          not_to include('separate deliveries')
      end

      it 'charges for each parcel once' do
        message = described_class.confirm_email(group)
        quoted = group.fulfillment_groups.sum { |parcel| parcel.cost }

        expect(quoted).to eq(group.delivery_total)
        expect(message.text_part.body.to_s).to include(group.display_delivery_total.to_s)
      end
    end

    describe 'goods that ship in no parcel' do
      before do
        digital_order = create(:order, store: store, order_group: group)
        create(:line_item, order: digital_order)
        group.reload
      end

      it 'still lists them, under their own heading' do
        parts_of(described_class.confirm_email(group)).each do |body|
          expect(body).to include('Nothing to ship')
          expect(body).to include(group.unfulfilled_line_items.first.name)
        end
      end
    end

    describe 'a buyer who gave a purchase order number' do
      before { group.orders.each { |order| order.update_columns(po_number: 'PO-4471') } }

      it 'reconciles against it in both parts' do
        parts_of(described_class.confirm_email(group.reload)).each do |body|
          expect(body).to include('PO-4471')
        end
      end
    end

    it 'renders in the locale the purchase was made in' do
      I18n.backend.store_translations(
        :'pt-BR', spree: { order_group_mailer: { confirm_email: { subject: 'Confirmação de Pedido' } } }
      )
      group.orders.each { |order| order.update_columns(locale: 'pt-BR') }

      expect(described_class.confirm_email(group.reload).subject).to include('Confirmação de Pedido')
    end
  end

  describe '#store_owner_notification_email' do
    before { store.update!(new_order_notifications_email: 'owner@example.com') }

    it 'goes to the address the store nominated' do
      expect(described_class.store_owner_notification_email(group).to).to eq(['owner@example.com'])
    end

    it 'describes the whole purchase' do
      parts_of(described_class.store_owner_notification_email(group)).each do |body|
        expect(body).to include(group.number)
        group.line_items.each { |line_item| expect(body).to include(line_item.name) }
      end
    end
  end
end
