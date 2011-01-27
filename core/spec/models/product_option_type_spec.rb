require File.dirname(__FILE__) + '/../spec_helper'

describe ProductOptionType do

  context 'validation' do
    it { should have_valid_factory(:product_option_type) }
  end

end
