Spree::Gateway::Bogus.create!(
  {
    :name => "Credit Card",
    :description => "Bogus payment gateway for development.",
    :environment => "development",
    :active => true
  }
)

Spree::Gateway::Bogus.create!(
  {
    :name => "Credit Card",
    :description => "Bogus payment gateway for production.",
    :environment => "production",
    :active => true
  }
)

Spree::Gateway::Bogus.create!(
  {
    :name => "Credit Card",
    :description => "Bogus payment gateway for staging.",
    :environment => "staging",
    :active => true
  }
)

Spree::Gateway::Bogus.create!(
  {
    :name => "Credit Card",
    :description => "Bogus payment gateway for test.",
    :environment => "test",
    :active => true
  }
)

Spree::PaymentMethod::Check.create!(
  {
    :name => "Check",
    :description => "Pay by check.",
    :active => true
  }
)
