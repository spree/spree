# -*- encoding: utf-8 -*-
# stub: spree_sample 4.8.0.beta ruby lib

Gem::Specification.new do |s|
  s.name = "spree_sample".freeze
  s.version = "4.8.0.beta".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "bug_tracker_uri" => "https://github.com/spree/spree/issues", "changelog_uri" => "https://github.com/spree/spree/releases/tag/v4.8.0.beta", "documentation_uri" => "https://dev-docs.spreecommerce.org/", "source_code_uri" => "https://github.com/spree/spree/tree/v4.8.0.beta" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Sean Schofield".freeze, "Spark Solutions".freeze]
  s.date = "2024-03-26"
  s.description = "Optional package containing example data of products, stores, shipping methods, categories and others to quickly setup a demo Spree store".freeze
  s.email = "hello@spreecommerce.org".freeze
  s.files = ["Gemfile".freeze, "LICENSE".freeze, "Rakefile".freeze, "db/samples.rb".freeze, "db/samples/addresses.rb".freeze, "db/samples/adjustments.rb".freeze, "db/samples/cms_feature_pages.rb".freeze, "db/samples/cms_homepages.rb".freeze, "db/samples/cms_sections.rb".freeze, "db/samples/cms_standard_pages.rb".freeze, "db/samples/data_feeds.rb".freeze, "db/samples/images/apache_baseball.png".freeze, "db/samples/images/ror_bag.jpeg".freeze, "db/samples/images/ror_baseball.jpeg".freeze, "db/samples/images/ror_baseball_back.jpeg".freeze, "db/samples/images/ror_baseball_jersey_back_blue.png".freeze, "db/samples/images/ror_baseball_jersey_back_green.png".freeze, "db/samples/images/ror_baseball_jersey_back_red.png".freeze, "db/samples/images/ror_baseball_jersey_blue.png".freeze, "db/samples/images/ror_baseball_jersey_green.png".freeze, "db/samples/images/ror_baseball_jersey_red.png".freeze, "db/samples/images/ror_jr_spaghetti.jpeg".freeze, "db/samples/images/ror_mug.jpeg".freeze, "db/samples/images/ror_mug_back.jpeg".freeze, "db/samples/images/ror_ringer.jpeg".freeze, "db/samples/images/ror_ringer_back.jpeg".freeze, "db/samples/images/ror_stein.jpeg".freeze, "db/samples/images/ror_stein_back.jpeg".freeze, "db/samples/images/ror_tote.jpeg".freeze, "db/samples/images/ror_tote_back.jpeg".freeze, "db/samples/images/ruby_baseball.png".freeze, "db/samples/images/spree_bag.jpeg".freeze, "db/samples/images/spree_jersey.jpeg".freeze, "db/samples/images/spree_jersey_back.jpeg".freeze, "db/samples/images/spree_mug.jpeg".freeze, "db/samples/images/spree_mug_back.jpeg".freeze, "db/samples/images/spree_ringer_t.jpeg".freeze, "db/samples/images/spree_ringer_t_back.jpeg".freeze, "db/samples/images/spree_spaghetti.jpeg".freeze, "db/samples/images/spree_stein.jpeg".freeze, "db/samples/images/spree_stein_back.jpeg".freeze, "db/samples/images/spree_tote_back.jpeg".freeze, "db/samples/images/spree_tote_front.jpeg".freeze, "db/samples/menu_items.rb".freeze, "db/samples/menus.rb".freeze, "db/samples/option_types.rb".freeze, "db/samples/option_values.rb".freeze, "db/samples/orders.rb".freeze, "db/samples/payment_methods.rb".freeze, "db/samples/payments.rb".freeze, "db/samples/product_properties.rb".freeze, "db/samples/products.rb".freeze, "db/samples/promotions.rb".freeze, "db/samples/properties.rb".freeze, "db/samples/prototypes.rb".freeze, "db/samples/reimbursements.rb".freeze, "db/samples/return_authorization_reasons.rb".freeze, "db/samples/shipping_methods.rb".freeze, "db/samples/stock.rb".freeze, "db/samples/stores.rb".freeze, "db/samples/tax_categories.rb".freeze, "db/samples/tax_rates.rb".freeze, "db/samples/taxonomies.rb".freeze, "db/samples/taxons.rb".freeze, "db/samples/variants.csv".freeze, "db/samples/variants.rb".freeze, "db/samples/zones.rb".freeze, "lib/spree/sample.rb".freeze, "lib/spree_sample.rb".freeze, "lib/tasks/sample.rake".freeze, "spree_sample.gemspec".freeze]
  s.homepage = "https://spreecommerce.org".freeze
  s.licenses = ["BSD-3-Clause".freeze]
  s.requirements = ["none".freeze]
  s.rubygems_version = "3.5.3".freeze
  s.summary = "Sample data for Spree Commerce".freeze

  s.installed_by_version = "3.5.3".freeze if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<spree_core>.freeze, [">= 4.8.0.beta".freeze])
  s.add_runtime_dependency(%q<ffaker>.freeze, ["~> 2.9".freeze])
end
