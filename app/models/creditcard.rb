class Creditcard < ActiveMerchant::Billing::CreditCard
  # Just a hack to make active_presenter happy (note the AM CreditCard class does not extend ActiveRecord::Base)
  def remove_attributes_protected_from_mass_assignment(attributes)
    attributes
  end
end