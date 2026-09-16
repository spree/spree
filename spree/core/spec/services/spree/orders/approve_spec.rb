require 'spec_helper'

module Spree
  describe Orders::Approve do
    subject { described_class }

    let(:order) { create(:completed_order_with_totals, considered_risky: true) }
    let(:user) { create(:admin_user) }

    let(:result) { subject.call(order: order, approver: user) }

    shared_examples 'approves order' do
      it { expect(result).to be_success }
      it { expect(result.value).to eq(order) }
      it { expect { result }.to change(order, :considered_risky).to(false) }
      it { expect { result }.to change { order.reload.approved_at }.from(nil) }
    end

    context 'with approver passed' do
      it_behaves_like 'approves order'

      it { expect { result }.to change(order, :approver).to(user) }

      it 'records which kind of actor it was' do
        result

        expect(order.reload.approver_type).to eq(Spree.admin_user_class.to_s)
      end
    end

    # The point of polymorphic actors: an integration approving through a
    # secret key is recorded as the key, not silently as whichever admin user
    # shares that numeric id.
    context 'when an API key approved it' do
      let(:user) { create(:api_key, :secret) }

      it_behaves_like 'approves order'

      it 'records the key' do
        result

        expect(order.reload.approver).to eq(user)
        expect(order.approver_type).to eq('Spree::ApiKey')
      end
    end

    context 'without approver passed' do
      let(:user) { nil }

      it_behaves_like 'approves order'
    end

    it 'publishes order.approved' do
      expect(order).to receive(:publish_event).with('order.approved')

      result
    end
  end
end
