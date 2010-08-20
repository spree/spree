require 'spec_helper'

describe TaxRate do
  context "match" do
    it "should ignore rates where the address does not match its zone"
    it "should use rates where the address matches is zone"
    it "should use the rate with the highest amount in the event of multiple matches"
  end
end