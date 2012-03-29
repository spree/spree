require 'spec_helper'

describe Spree::Image do

  context "shoulda validations" do
    it { should have_attached_file(:attachment) }
    it { should validate_attachment_presence(:attachment) }
  end

end
