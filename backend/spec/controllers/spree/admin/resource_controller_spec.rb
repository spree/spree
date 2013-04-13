require 'spec_helper'

describe Spree::Admin::ResourceController do
  stub_authorization!

  describe "POST#update_positions" do
    before do
      Spree::Admin::ResourceController.any_instance.stub(:model_class).and_return(Spree::Variant)
    end

    let(:variant) { create(:variant) }

    it "has 1 as initial position when created" do
      variant.position.should == 1
    end

    it "returns Ok on json" do
      variant2 = create(:variant)
      expect {
				spree_post :update_positions, id: variant.id, positions: { variant.id => "2", variant2.id => "1" }, format: "js"
        variant.reload
      }.to change(variant, :position).from(1).to(2)
    end
  end
end
