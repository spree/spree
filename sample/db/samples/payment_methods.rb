Spree::Gateway::Bogus.create!(
  {
    :name => "כרטיס אשראי",
    :description => "בדיקת סליקה לכרטיס אשראי.",
    :environment => "development",
    :active => true
  }
)

Spree::Gateway::Bogus.create!(
  {
    :name => "כרטיס אשראי",
    :description => "בדיקת סליקה לכרטיס אשראי.",
    :environment => "production",
    :active => true
  }
)

Spree::Gateway::Bogus.create!(
  {
    :name => "כרטיס אשראי",
    :description => "בדיקת סליקה לכרטיס אשראי.",
    :environment => "staging",
    :active => true
  }
)

Spree::Gateway::Bogus.create!(
  {
    :name => "כרטיס אשראי",
    :description => "בדיקת סליקה לכרטיס אשראי.",
    :environment => "test",
    :active => true
  }
)

Spree::PaymentMethod::Check.create!(
  {
    :name => "צ׳ק",
    :description => "שלם בצ׳ק.",
    :active => true
  }
)
