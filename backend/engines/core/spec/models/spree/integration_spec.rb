require 'spec_helper'

# We have no concrete integrations yet so this is just to check that the base model is valid
RSpec.describe Spree::Integration, type: :model do
  subject(:integration) { build(:integration) }

  it { is_expected.to be_valid }
end
