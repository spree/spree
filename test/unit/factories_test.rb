require 'test_helper'

class FactoriesTest < ActiveSupport::TestCase
  fixtures :payment_methods, :countries

  (Factory.factories.keys - [:global_zone]).each do |factory|
    context factory.to_s do
      should "generate valid record" do
        Timeout.timeout(2) do
          assert Factory.build(factory).valid?
        end
      end
    end
  end

  [:adjustment, :charge, :credit].each do |charge_type|
    context "#{charge_type} factory" do
      should "return correct classes" do
        assert_equal(charge_type.to_s.camelize, Factory.build(charge_type).class.name)
      end
    end
  end

  context "TaxCategory" do
    should "create tax rate" do
      assert(Factory(:tax_category).tax_rates.reload.first, "tax rate was not created.")
    end
  end
end
