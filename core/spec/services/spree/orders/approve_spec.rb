require 'spec_helper'

module Spree
  describe Orders::Approve do
    subject { described_class }

    let(:order) { create(:completed_order_with_totals, considered_risky: true) }
    let(:user) { create(:user) }

    let(:result) { subject.call(order: order, approver: user) }

    shared_examples 'approves order' do
      it { expect(result).to be_success }
      it { expect(result.value).to eq(order) }
      it { expect { result }.to change(order, :considered_risky).to(false) }
    end

    context 'with approver passed' do
      it_behaves_like 'approves order'

      it { expect { result }.to change(order, :approver).to(user) }
    end

    context 'without approver passed' do
      let(:user) { nil }

      it_behaves_like 'approves order'
    end
  end
end
