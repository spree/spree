require 'spec_helper'

module Spree
  describe Orders::Cancel do
    subject { described_class }

    let(:order) { create(:completed_order_with_totals) }
    let!(:user) { create(:user) }

    let(:result) { subject.call(order: order, canceler: user) }

    shared_examples 'tries to cancel' do
      context 'completed order' do
        it { expect(result).to be_success }
        it { expect { result }.to change(order, :state).to('canceled') }
        it { expect(result.value).to eq(order) }
      end

      context 'incomplete order' do
        let(:order) { create(:order_with_totals) }

        it { expect(result).to be_failure }
        it { expect(result.error).to be_present }
      end
    end

    context 'with canceler passed' do
      it_behaves_like 'tries to cancel'

      it { expect { result }.to change(order, :canceler).to(user) }
    end

    context 'without canceler passed' do
      let(:user) { nil }

      it_behaves_like 'tries to cancel'
    end
  end
end
