require 'spec_helper'

module Spree
  describe CheckoutHelper, type: :helper do
    describe '#checkout_progress' do
      before do
        @order = create(:order, state: 'address')
      end

      it 'does not include numbers by default' do
        output = checkout_progress
        expect(output).not_to include('1. Address')
      end

      it 'has option to include numbers' do
        output = checkout_progress(numbers: true)
        expect(output).to include('1. Address')
      end
    end
  end
end
