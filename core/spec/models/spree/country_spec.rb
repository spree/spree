require 'spec_helper'

describe Spree::Country do
  it "can find all countries group by states required" do
    country_states_required= Spree::Country.create({:name => "Canada", :iso_name => "CAN", :states_required => true})
    country_states_not_required= Spree::Country.create({:name => "France", :iso_name => "FR", :states_required => false})
    states_required = Spree::Country.states_required_by_country_id
    states_required[country_states_required.id.to_s].should be_true
    states_required[country_states_not_required.id.to_s].should be_false
  end

  it "returns that the states are required for an invalid country" do
    Spree::Country.states_required_by_country_id['i do not exit'].should be_true
  end

  context 'country instance' do
    let(:country) { create(:country) }

    context "country has no orders" do
      context "#destroy" do
        it "should set deleted_at value" do
          country.destroy
          country.deleted_at.should_not be_nil
        end
      end
    end

    context "country has orders" do
      before do
        address = create(:address, :country => country)
        @order = create(:order, :shipping_address => address)
      end

      context "#destroy" do
        it "should set deleted_at value" do
          country.destroy
          country.deleted_at.should_not be_nil
          @order.shipping_address.country.should_not be_nil
        end
      end
    end
  end

end
