Gem::Specification.new do |s|
  s.name = %q{calendar_date_select}
  s.version = "1.11.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Tim Harper"]
  s.date = %q{2008-11-23}
  s.description = %q{}
  s.email = ["tim c harper at gmail dot com"]
  s.extra_rdoc_files = ["History.txt", "Manifest.txt", "Readme.txt"]
  s.files = ["History.txt", "init.rb", "js_test/functional/cds_test.html", "js_test/prototype.js", "js_test/test.css", "js_test/unit/cds_helper_methods.html", "js_test/unittest.js", "lib/calendar_date_select/calendar_date_select.rb", "lib/calendar_date_select/includes_helper.rb", "lib/calendar_date_select.rb", "Manifest.txt", "MIT-LICENSE", "public/blank_iframe.html", "public/images/calendar_date_select/calendar.gif", "public/javascripts/calendar_date_select/calendar_date_select.js", "public/javascripts/calendar_date_select/format_american.js", "public/javascripts/calendar_date_select/format_db.js", "public/javascripts/calendar_date_select/format_euro_24hr.js", "public/javascripts/calendar_date_select/format_euro_24hr_ymd.js", "public/javascripts/calendar_date_select/format_finnish.js", "public/javascripts/calendar_date_select/format_hyphen_ampm.js", "public/javascripts/calendar_date_select/format_iso_date.js", "public/javascripts/calendar_date_select/format_italian.js", "public/javascripts/calendar_date_select/locale/de.js", "public/javascripts/calendar_date_select/locale/fi.js", "public/javascripts/calendar_date_select/locale/fr.js", "public/javascripts/calendar_date_select/locale/pl.js", "public/javascripts/calendar_date_select/locale/pt.js", "public/javascripts/calendar_date_select/locale/ru.js", "public/stylesheets/calendar_date_select/blue.css", "public/stylesheets/calendar_date_select/default.css", "public/stylesheets/calendar_date_select/plain.css", "public/stylesheets/calendar_date_select/red.css", "public/stylesheets/calendar_date_select/silver.css", "Rakefile", "Readme.txt", "test/functional/calendar_date_select_test.rb", "test/functional/helper_methods_test.rb", "test/test_helper.rb"]
  s.has_rdoc = true
  s.homepage = %q{http://code.google.com/p/calendardateselect/}
  s.rdoc_options = ["--main", "README.txt"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{calendar_date_select}
  s.rubygems_version = %q{1.3.0}
  s.summary = %q{}
  s.test_files = ["test/test_helper.rb"]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<hoe>, [">= 1.8.0"])
    else
      s.add_dependency(%q<hoe>, [">= 1.8.0"])
    end
  else
    s.add_dependency(%q<hoe>, [">= 1.8.0"])
  end
end
