require File.dirname(__FILE__) + '/../test_helper'
require 'fileutils'

class CommentingGeneratorTest < ActiveSupport::TestCase

  def test_ensure_comments_dont_exist
    # make sure the comments are already defined
    assert_equal false, Object.send(:const_defined?, :Comment)
    assert_equal false, Object.send(:const_defined?, :Commenting)
  end

  def test_ensure_files_exist_after_generator_runs
    run_generator

    # make sure the files are there
    for generated_file in generated_files do
      assert File.exists?(File.expand_path(generated_file))
    end
  end

  def test_classes_exist_with_associations
    run_generator
    assert_nothing_raised { Commenting }
    assert_nothing_raised { Comment }
    citation = Citation.find(:first)
    assert !citation.nil?
    assert citation.respond_to?(:comments)
    user = User.find(:first)
    assert !user.nil?
    assert user.respond_to?(:comments)
  end

  def teardown
    Object.send(:remove_const, :Comment) if Object.send(:const_defined?, :Comment)
    Object.send(:remove_const, :Commenting) if Object.send(:const_defined?, :Commenting)
    remove_all_generated_files
    remove_require_for_commenting_extensions
  end

  def generated_files    
    generated_files = [File.join(File.dirname(__FILE__), '..', '..', 'app', 'models', 'comment.rb')]
    generated_files << File.join(File.dirname(__FILE__), '..', '..', 'app', 'models', 'commenting.rb')
    generated_files << File.join(File.dirname(__FILE__), '..', '..', 'test', 'unit', 'commenting_test.rb')
    generated_files << File.join(File.dirname(__FILE__), '..', '..', 'test', 'unit', 'comment_test.rb')
    generated_files << File.join(File.dirname(__FILE__), '..', '..', 'lib', 'commenting_extensions.rb')
    generated_files << File.join(File.dirname(__FILE__), '..', '..', 'test', 'fixtures', 'comments.yml')
    generated_files << File.join(File.dirname(__FILE__), '..', '..', 'test', 'fixtures', 'commentings.yml')
  end

  def remove_all_generated_files
    for generated_file in generated_files do
      if File.exists?(generated_file)
        assert FileUtils.rm(generated_file)
      end
    end
  end

  def run_migrate
    `rake db:migrate RAILS_ENV=test`
  end

  def run_generator
    command = File.join(File.dirname(__FILE__), '..', '..', 'script', 'generate')
    `#{command} commenting Citation User`
    run_migrate
  end

  def remove_require_for_commenting_extensions  
    environment = File.join(File.dirname(__FILE__), '..', '..', 'config', 'environment.rb')
    new_environment = ''
    if File.exists?(environment)
      if (open(environment) { |file| file.grep(/Rails/).any? })
        IO.readlines(environment).each do |line|
          new_environment += line unless line.match(/commenting_extensions/i)
        end
        File.open(environment, "w+") do |f|
          f.pos = 0
          f.print new_environment
        end
      end
    end
  end
end
