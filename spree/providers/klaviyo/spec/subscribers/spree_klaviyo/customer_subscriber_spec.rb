require 'spec_helper'

RSpec.describe SpreeKlaviyo::CustomerSubscriber do
  let(:store) { @default_store }
  let(:customer) { create(:customer) }

  it 'listens under the event prefix customers publish with' do
    prefix = Spree.customer_class.event_prefix

    expect(described_class.subscription_patterns).to contain_exactly("#{prefix}.created", "#{prefix}.updated")
  end

  def handle(name, store: self.store)
    described_class.new.call(spree_event(name, { id: customer.prefixed_id }, store: store))
  end

  context 'with an active Klaviyo integration' do
    let!(:integration) { create(:klaviyo_integration, :active, store: store) }

    %w[user.created user.updated].each do |name|
      it "syncs the profile on #{name}" do
        expect { handle(name) }.to have_enqueued_job(SpreeKlaviyo::SyncProfileJob).with(integration, customer)
      end
    end

    it 'syncs nothing when the event names another store' do
      expect { handle('user.updated', store: create(:store)) }.not_to enqueue_a_klaviyo_job
    end
  end

  it 'enqueues nothing without a Klaviyo integration' do
    expect { handle('user.created') }.not_to enqueue_a_klaviyo_job
  end

  it 'enqueues nothing for an inactive integration' do
    create(:klaviyo_integration, store: store, active: false)

    expect { handle('user.created') }.not_to enqueue_a_klaviyo_job
  end
end
