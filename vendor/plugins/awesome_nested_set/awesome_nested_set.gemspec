# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{awesome_nested_set}
  s.version = "1.4.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Brandon Keepers", "Daniel Morrison"]
  s.date = %q{2009-09-08}
  s.description = %q{An awesome nested set implementation for Active Record}
  s.email = %q{info@collectiveidea.com}
  s.extra_rdoc_files = [
    "README.rdoc"
  ]
  s.files = [
    ".autotest",
     ".gitignore",
     "MIT-LICENSE",
     "README.rdoc",
     "Rakefile",
     "VERSION",
     "awesome_nested_set.gemspec",
     "init.rb",
     "lib/awesome_nested_set.rb",
     "lib/awesome_nested_set/helper.rb",
     "rails/init.rb",
     "test/application.rb",
     "test/awesome_nested_set/helper_test.rb",
     "test/awesome_nested_set_test.rb",
     "test/db/database.yml",
     "test/db/schema.rb",
     "test/fixtures/categories.yml",
     "test/fixtures/category.rb",
     "test/fixtures/departments.yml",
     "test/fixtures/notes.yml",
     "test/test_helper.rb"
  ]
  s.homepage = %q{http://github.com/collectiveidea/awesome_nested_set}
  s.rdoc_options = ["--main", "README.rdoc", "--inline-source", "--line-numbers"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.3}
  s.summary = %q{An awesome nested set implementation for Active Record}
  s.test_files = [
    "test/db/database.yml",
     "test/fixtures/categories.yml",
     "test/fixtures/departments.yml",
     "test/fixtures/notes.yml",
     "test/application.rb",
     "test/awesome_nested_set/helper_test.rb",
     "test/awesome_nested_set_test.rb",
     "test/db/schema.rb",
     "test/fixtures/category.rb",
     "test/test_helper.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<activerecord>, [">= 1.1"])
    else
      s.add_dependency(%q<activerecord>, [">= 1.1"])
    end
  else
    s.add_dependency(%q<activerecord>, [">= 1.1"])
  end
end
