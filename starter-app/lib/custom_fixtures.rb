require 'active_record/fixtures'

class Fixtures < YAML::Omap
  def delete_existing_fixtures
    # do nothing - we're intentionally not emptying the database since it has some structural data in it
  end
end    
