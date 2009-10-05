require 'active_merchant/billing/integrations/notification'
require 'active_merchant/billing/integrations/helper'
require 'active_merchant/billing/integrations/return'
require 'active_merchant/billing/integrations/bogus'
require 'active_merchant/billing/integrations/chronopay'
require 'active_merchant/billing/integrations/paypal'
require 'active_merchant/billing/integrations/nochex'
require 'active_merchant/billing/integrations/gestpay'
require 'active_merchant/billing/integrations/two_checkout'
require 'active_merchant/billing/integrations/hi_trust'
require 'active_merchant/billing/integrations/quickpay'

# make the bogus gateway be classified correctly by the inflector
if defined?(ActiveSupport::Inflector)
  ActiveSupport::Inflector.inflections do |inflect|
    inflect.uncountable 'bogus'
  end
else
  Inflector.inflections do |inflect|
    inflect.uncountable 'bogus'
  end
end
