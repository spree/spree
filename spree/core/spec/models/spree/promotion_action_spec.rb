require 'spec_helper'

describe Spree::PromotionAction, type: :model do

  it_behaves_like 'type labels'

  it "forces developer to implement 'perform' method" do
    stub_const('Spree::BadTestAction', Class.new(described_class))

    expect { Spree::BadTestAction.new.perform }.to raise_error(RuntimeError, /perform should be implemented/)
  end
end
