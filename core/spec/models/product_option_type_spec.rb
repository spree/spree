require 'spec_helper'

describe Spree::ProductOptionType do

  context 'validation' do
    it { should have_valid_factory(:product_option_type) }
  end

end
