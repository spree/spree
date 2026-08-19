require 'spec_helper'

# The state machines are gone, but the public verbs they generated were API
# that extensions and host apps call. Each keeps working for one release with
# a warning, delegating to the workflow that replaced it.
RSpec.describe 'deprecated transition verbs' do
  let(:store) { Spree::Store.default }

  before { allow(Spree::Deprecation).to receive(:warn) }

  describe Spree::Product do
    let(:product) { create(:product, status: 'draft', store: store) }

    it 'activate! delegates to the workflow' do
      expect { product.activate! }.to change { product.reload.status }.from('draft').to('active')
      expect(Spree::Deprecation).to have_received(:warn).with(/activate!/)
    end

    it 'archive! delegates to the workflow' do
      expect { product.archive! }.to change { product.reload.status }.to('archived')
    end

    it 'draft! delegates to the workflow' do
      product.update!(status: 'active')

      expect { product.draft! }.to change { product.reload.status }.from('active').to('draft')
    end
  end

  describe Spree::GiftCard do
    let(:gift_card) { create(:gift_card, store: store, amount: 50) }

    it 'redeem! marks a spent card redeemed' do
      gift_card.update!(amount_used: 50)

      expect { gift_card.redeem! }.to change { gift_card.reload.status }.from('active').to('redeemed')
      expect(Spree::Deprecation).to have_received(:warn).with(/redeem!/)
    end

    it 'partial_redeem! leaves a card with a balance spendable' do
      gift_card.update!(amount_used: 20)

      expect { gift_card.partial_redeem! }.to change { gift_card.reload.status }.to('partially_redeemed')
    end

    it 'cancel! voids an unspent card' do
      expect { gift_card.cancel! }.to change { gift_card.reload.status }.from('active').to('canceled')
    end

    it 'raises when the workflow refuses' do
      gift_card.update!(status: 'redeemed', amount_used: 50)

      expect { gift_card.redeem! }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe Spree::PriceList do
    let(:price_list) { create(:price_list, store: store) }

    it 'activate keeps the old event\'s literal behaviour' do
      expect { price_list.activate }.to change { price_list.reload.status }.from('draft').to('active')
    end

    # The workflow would schedule this one; the shell must not, or a caller
    # upgrading finds its lists silently in a different status.
    it 'activate goes straight to active even with a future start date' do
      price_list.update!(starts_at: 1.week.from_now)

      price_list.activate

      expect(price_list.reload.status).to eq('active')
    end

    it 'deactivate delegates to the workflow' do
      price_list.update!(status: 'active')

      expect { price_list.deactivate }.to change { price_list.reload.status }.to('inactive')
    end

    it 'schedule still sets the status directly' do
      expect { price_list.schedule }.to change { price_list.reload.status }.to('scheduled')
    end
  end

  describe Spree::Invitation do
    let(:invitation) { create(:invitation, invitee: create(:admin_user, :without_admin_role)) }

    it 'accept! delegates to the workflow' do
      expect { invitation.accept! }.to change { invitation.reload.status }.from('pending').to('accepted')
    end

    it 'accept returns false rather than raising when refused' do
      invitation.update_column(:expires_at, 1.day.ago)

      expect(invitation.accept).to be(false)
      expect(invitation.reload.status).to eq('pending')
    end

    it 'accept! raises when refused' do
      invitation.update_column(:expires_at, 1.day.ago)

      expect { invitation.accept! }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe Spree::Import do
    let(:import) { create(:product_import, owner: store) }

    it 'start_mapping! delegates to the workflow' do
      expect { import.start_mapping! }.to change { import.reload.status }.from('pending').to('mapping')
      expect(import.mappings.count).to be > 0
    end

    it 'retry_failed_rows returns false when there is nothing to retry' do
      import.update!(status: 'completed')

      expect(import.retry_failed_rows).to be(false)
    end
  end

  describe Spree::ImportRow do
    let(:import) { create(:product_import, owner: store) }
    let(:row) { create(:import_row, import: import) }

    it 'complete! writes the status and publishes' do
      expect { row.complete! }.to change { row.reload.status }.from('pending').to('completed')
    end

    it 'fail! writes the status' do
      expect { row.fail! }.to change { row.reload.status }.to('failed')
    end
  end

  describe Spree::FulfillmentItem do
    let(:order) { create(:order_ready_to_ship) }
    let(:item) { order.fulfillments.first.fulfillment_items.first }

    it 'return! moves a shipped item to returned' do
      item.update!(status: 'shipped')

      expect { item.return! }.to change { item.reload.status }.from('shipped').to('returned')
    end

    it 'return! leaves an unshipped item alone' do
      expect(item.return!).to be(false)
    end
  end
end
