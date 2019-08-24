# In Spree prior to version 4.0.0 promotion and tax calculator files
# where mixed together in the main calculator folder.
# Calculators are now organised into modules: promotion, returns, shipping, tax.
# As well as the lack of organisation, FlatPercentItemTotal was doing the same as PercentOnLineItem
# and cross refrenced in the spec tests, this has been unifed into one file -> FlatPercent
# In this file we point to old locatins at the new locations as not to brake older versions of Spree.

# PROMOTION moved From => To
Spree::Calculator::FlatPercentItemTotal           = Spree::Calculator::Promotion::FlatPercent
Spree::Calculator::PercentOnLineItem              = Spree::Calculator::Promotion::FlatPercent
Spree::Calculator::FlatRate                       = Spree::Calculator::Promotion::FlatRate
Spree::Calculator::FlexiRate                      = Spree::Calculator::Promotion::FlexiRate
Spree::Calculator::PriceSack                      = Spree::Calculator::Promotion::PriceSack
Spree::Calculator::TieredFlatRate                 = Spree::Calculator::Promotion::TieredFlatRate
Spree::Calculator::TieredPercent                  = Spree::Calculator::Promotion::TieredPercent

# SHIPPING was moved From => To
Spree::Calculator::Shipping::FlatPercentItemTotal = Spree::Calculator::Shipping::FlatPercent
