require 'spec_helper'

# This is a bit of a insane spec I have to admit
# Chosed the spree_payment_methods table because it has a `name` column
# already. Stubs wouldn't work here (the delegation runs before this spec is
# loaded) and adding a column here might make the test even crazy so here we go
module Spree
  class DelegateBelongsToStubModel < Spree::Base
    self.table_name = "spree_payment_methods"
    belongs_to :product
    delegate_belongs_to :product, :name
  end

  describe DelegateBelongsToStubModel do
    context "model has column attr delegated to associated object" do
      it "doesnt touch the associated object" do
        expect(subject).not_to receive(:product)
        subject.name
      end
    end
  end 
end
