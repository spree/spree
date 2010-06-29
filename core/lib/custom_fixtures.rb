require 'active_record/fixtures'

class Fixtures < (RUBY_VERSION < '1.9' ? YAML::Omap : Hash)
  def delete_existing_fixtures
    # do nothing - we're intentionally not emptying the database since it has some structural data in it
  end
end    
