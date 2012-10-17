require 'spec_helper'

module Spree
  class GatewayWithPassword < PaymentMethod
    attr_accessible :preferred_password

    preference :password, :string, :default => "password"
  end
end

module Spree
  describe Admin::PaymentMethodsController do
    let(:payment_method) { Spree::GatewayWithPassword.create!(:name => "Bogus", :preferred_password => "haxme") }

    # regression test for #2094
    it "does not clear password on update" do
      payment_method.preferred_password.should == "haxme"
      spree_put :update, :id => payment_method.id, :payment_method => { :type => payment_method.class.to_s, :preferred_password => "" } 
      response.should redirect_to(spree.edit_admin_payment_method_path(payment_method))

      payment_method.reload
      payment_method.preferred_password.should == "haxme"
    end

  end
end
