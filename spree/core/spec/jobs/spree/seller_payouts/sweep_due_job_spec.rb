require 'spec_helper'

RSpec.describe Spree::SellerPayouts::SweepDueJob do
  let(:store) { @default_store }
  let(:seller) { create(:seller, :approved, store: store) }

  def earn(amount, seller: nil, currency: 'USD')
    owner = seller || self.seller
    create(:seller_transfer, :completed, seller: owner, currency: currency, amount: amount,
                                         order: create(:order, store: owner.store, seller: owner, currency: currency))
  end

  it 'settles a seller who is owed money' do
    earn(40)

    expect { described_class.perform_now }.to change { Spree::SellerPayout.count }.by(1)
  end

  it 'leaves a seller who has earned nothing' do
    seller

    expect { described_class.perform_now }.not_to change { Spree::SellerPayout.count }
  end

  # The operator settles these by hand, so nothing schedules them.
  it 'never settles a seller on a manual schedule' do
    seller.update!(payouts_schedule_interval: 'manual')
    earn(40)

    expect { described_class.perform_now }.not_to change { Spree::SellerPayout.count }
  end

  it 'ignores a seller who is not approved' do
    pending_seller = create(:seller, store: store, status: 'pending')
    earn(40, seller: pending_seller)

    expect { described_class.perform_now }.not_to change { Spree::SellerPayout.count }
  end

  it 'settles each currency a seller is owed in separately' do
    earn(40)
    earn(30, currency: 'EUR')

    described_class.perform_now

    expect(seller.seller_payouts.pluck(:currency, :amount)).to contain_exactly(['USD', 40], ['EUR', 30])
  end

  # Every marketplace on the installation is swept, each seller reached
  # through the store that owns them.
  it 'settles sellers across every store' do
    other_store = create(:store)
    other_seller = create(:seller, :approved, store: other_store)
    earn(40)
    earn(30, seller: other_seller)

    described_class.perform_now

    expect(seller.seller_payouts.count).to eq(1)
    expect(other_seller.seller_payouts.count).to eq(1)
  end

  # One stuck seller must not end the run for everyone behind them.
  it 'carries on past a seller whose settlement fails' do
    other_seller = create(:seller, :approved, store: store)
    earn(40)
    earn(30, seller: other_seller)
    allow(Spree).to receive(:seller_payout_sweep_workflow).and_wrap_original do |original|
      workflow = original.call
      failing = seller
      Class.new do
        define_singleton_method(:call) do |seller:, currency:|
          raise StandardError, 'provider down' if seller.id == failing.id

          workflow.call(seller: seller, currency: currency)
        end
      end
    end

    described_class.perform_now

    expect(seller.seller_payouts.count).to eq(0)
    expect(other_seller.seller_payouts.count).to eq(1)
  end
end
