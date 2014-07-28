require 'spec_helper'

describe Spree::Promotion::Rules::OneUsePerUser do
  let(:rule) { described_class.new }

  describe '#eligible?(order)' do
    subject { rule.eligible?(order) }
    let(:order) { double Spree::Order, user: user }
    let(:user) { double Spree::LegacyUser }
    let(:promotion) { stub_model Spree::Promotion, used_by?: used_by }
    let(:used_by) { false }

    before { rule.promotion = promotion }

    context 'when the order is assigned to a user' do
      context 'when the user has used this promotion before' do
        let(:used_by) { true }

        it { should be false }
      end

      context 'when the user has not used this promotion before' do
        it { should be true }
      end
    end

    context 'when the order is not assigned to a user' do
      let(:user) { nil }
      it { should be false }
    end
  end
end
