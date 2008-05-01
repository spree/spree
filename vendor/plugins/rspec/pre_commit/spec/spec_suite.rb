class SpecSuite
  def run
    system("ruby rspec/spec/rspec_suite.rb") || raise("Rspec Suite FAILED")
    system("ruby rspec_on_rails/spec/rails_suite.rb") || raise("Rails Suite FAILED")
    system("ruby cached_example_rails_app/spec/rails_app_suite.rb") || raise("Rails App Suite FAILED")
  end
end

if $0 == __FILE__
  SpecSuite.new.run
end
