# Uncomment this if you reference any of your controllers in activate
# require_dependency 'application'

class CalculatorsExtension < Spree::Extension
  version "1.0"
  description "Extension for calculators"
  url "http://spreecomerce.com"

  # Please use calculators/config/routes.rb instead for extension routes.

  # def self.require_gems(config)
  #   config.gem "gemname-goes-here", :version => '1.2.3'
  # end
  
  def activate 
    [
      Calculator::FlatPercentItemTotal,
      Calculator::FlatRate,
      Calculator::FlexiRate,
      Calculator::PerItem,
      Calculator::SalesTax,
      Calculator::Vat,
    ].each(&:register)
  end
end
