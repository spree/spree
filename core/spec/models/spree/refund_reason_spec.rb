require 'spec_helper'

describe Spree::RefundReason do
  describe 'Associations' do
    it { is_expected.to have_many(:refunds).dependent(:restrict_with_error) }
  end
end
