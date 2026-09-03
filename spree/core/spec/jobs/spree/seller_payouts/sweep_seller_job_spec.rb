require 'spec_helper'

RSpec.describe Spree::SellerPayouts::SweepSellerJob do
  let(:store) { @default_store }
  let(:seller) { create(:seller, :approved, store: store) }

  def earn(amount, seller: nil, currency: 'USD')
    owner = seller || self.seller
    create(:seller_transfer, :completed, seller: owner, currency: currency, amount: amount,
                                         order: create(:order, store: owner.store, seller: owner, currency: currency))
  end

  it 'settles a seller who is owed money' do
    earn(40)

    expect { described_class.perform_now(seller.id) }.to change { Spree::SellerPayout.count }.by(1)
  end

  it 'leaves a seller who has earned nothing' do
    expect { described_class.perform_now(seller.id) }.not_to change { Spree::SellerPayout.count }
  end

  # The operator settles these by hand, so nothing schedules them.
  it 'never settles a seller on a manual schedule' do
    seller.update!(payouts_schedule_interval: 'manual')
    earn(40)

    expect { described_class.perform_now(seller.id) }.not_to change { Spree::SellerPayout.count }
  end

  it 'settles each currency a seller is owed in separately' do
    earn(40)
    earn(30, currency: 'EUR')

    described_class.perform_now(seller.id)

    expect(seller.seller_payouts.pluck(:currency, :amount)).to contain_exactly(['USD', 40], ['EUR', 30])
  end

  # A failed payout released its earnings back to the next sweep, so counting
  # it as a settlement would block the retry it exists to allow.
  it 'retries a seller whose last settlement failed' do
    earn(40)
    create(:seller_payout, seller: seller, currency: 'USD', status: 'failed', amount: 0)

    expect { described_class.perform_now(seller.id) }.
      to change { Spree::SellerPayout.where(status: 'pending').count }.by(1)
  end

  it 'still waits when the last settlement went out' do
    earn(40)
    create(:seller_payout, seller: seller, currency: 'USD', status: 'completed', amount: 40)

    expect { described_class.perform_now(seller.id) }.not_to change { Spree::SellerPayout.count }
  end

  # A seller can be deleted between the fan-out and the job running.
  it 'does nothing for a seller that has gone' do
    expect { described_class.perform_now(-1) }.not_to raise_error
  end

  # Confirming an earning is the transfer level's business, on its own
  # schedule — see Spree::SellerTransfers::ExecutePendingDueJob.
  it 'leaves an unconfirmed earning to the job that owns it' do
    create(:seller_transfer, seller: seller, amount: 40, status: 'processing',
                             order: create(:order, store: store, seller: seller))

    expect { described_class.perform_now(seller.id) }.
      not_to have_enqueued_job(Spree::SellerTransfers::ExecutePendingJob)
  end
end
