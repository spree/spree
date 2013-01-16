# Other base_helper tests are located in core
require 'spec_helper'

module Spree
  describe BaseHelper do
    include Spree::BaseHelper
    # Regression test for #889
    context "seo_url" do
      let(:taxon) { stub(:permalink => "bam") }
      it "provides the correct URL" do
        seo_url(taxon).should == "/t/bam"
      end
    end
  end
end
