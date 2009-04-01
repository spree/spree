require 'fileutils'
require File.dirname(__FILE__) + '/../test_helper'

class TaggingGeneratorTest < ActiveSupport::TestCase
  
  def setup
    Dir.chdir RAILS_ROOT do
      truncate

      # Revert environment lib requires
      FileUtils.cp "config/environment.rb.canonical", "config/environment.rb"
      
      # Delete generator output
      ["app/models/tag.rb", "app/models/tagging.rb", 
        "test/unit/tag_test.rb", "test/unit/tagging_test.rb", 
        "test/fixtures/tags.yml", "test/fixtures/taggings.yml",
        "lib/tagging_extensions.rb",
        "db/migrate/010_create_tags_and_taggings.rb"].each do |file|
          File.delete file if File.exist? file
      end
      
      # Rebuild database
      Echoe.silence do
        system("ruby #{HERE}/setup.rb")
      end
    end
  end
  
  alias :teardown :setup

  def test_generator
    Dir.chdir RAILS_ROOT do
      Echoe.silence do
        assert system("script/generate tagging Stick Stone -q -f")
        assert system("rake db:migrate")
        assert system("rake db:fixtures:load")
        assert system("rake test:units")      
      end
    end
  end
  
end
