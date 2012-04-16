require 'spec_helper'

describe Spree::Country do
  context "shoulda validations" do
    it { should have_valid_factory(:country) }
  end

end
