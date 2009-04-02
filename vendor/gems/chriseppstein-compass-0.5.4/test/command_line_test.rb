require  File.dirname(__FILE__)+'/test_helper'
require 'fileutils'
require 'compass'
require 'compass/exec'
require 'timeout'

class CommandLineTest < Test::Unit::TestCase
  include Compass::TestCaseHelper

  def teardown
    Compass.configuration.reset!
  end

  def test_basic_install
    within_tmp_directory do
      compass "basic"
      assert File.exists?("basic/src/screen.sass")
      assert File.exists?("basic/stylesheets/screen.css")
      assert_action_performed :directory, "basic/"
      assert_action_performed    :create, "basic/src/screen.sass"
      assert_action_performed   :compile, "basic/src/screen.sass"
      assert_action_performed    :create, "basic/stylesheets/screen.css"
    end
  end

  def test_framework_installs
    Compass::Frameworks::ALL.each do |framework|
      within_tmp_directory do
        compass *%W(--framework #{framework.name} #{framework.name}_project)
        assert File.exists?("#{framework.name}_project/src/screen.sass")
        assert File.exists?("#{framework.name}_project/stylesheets/screen.css")
        assert_action_performed :directory, "#{framework.name}_project/"
        assert_action_performed    :create, "#{framework.name}_project/src/screen.sass"
        assert_action_performed   :compile, "#{framework.name}_project/src/screen.sass"
        assert_action_performed    :create, "#{framework.name}_project/stylesheets/screen.css"
      end
    end
  end

  def test_basic_update
    within_tmp_directory do
      compass "basic"
      Dir.chdir "basic" do
        compass
        assert_action_performed :compile, "src/screen.sass"
        assert_action_performed :identical, "stylesheets/screen.css"
      end
    end
  end

  def test_rails_install
    within_tmp_directory do
      generate_rails_app("compass_rails")
      Dir.chdir "compass_rails" do
        compass("--rails", ".") do |responder|
          responder.respond_to "Is this OK? (Y/n) ", :with => "Y"
          responder.respond_to "Emit compiled stylesheets to public/stylesheets/compiled/? (Y/n) ", :with => "Y"
        end
        # puts @last_result
        assert_action_performed :create, "./app/stylesheets/screen.sass"
        assert_action_performed :create, "./config/initializers/compass.rb"
      end
    end
  rescue LoadError
    puts "Skipping rails test. Couldn't Load rails"
  end

  protected
  def compass(*arguments)
    if block_given?
      responder = Responder.new
      yield responder
      IO.popen("-", "w+") do |io|
        if io
          #parent process
          output = ""
          while !io.eof?
            timeout(1) do
              output << io.readpartial(512)
            end
            prompt = output.split("\n").last
            if response = responder.response_for(prompt)
              io.puts response
            end
          end
          @last_result = output
        else
          #child process
          execute *arguments
        end
      end
    else
      @last_result = capture_output do
        execute *arguments
      end
    end
  rescue Timeout::Error
    fail "Read from child process timed out"
  end

  class Responder
    def initialize
      @responses = []
    end
    def respond_to(prompt, options = {})
      @responses << [prompt, options[:with]]
    end
    def response_for(prompt)
      pair = @responses.detect{|r| r.first == prompt}
      pair.last if pair
    end
  end

  def assert_action_performed(action, path)
    @last_result.split("\n").each do |line|
      line = line.split
      return if line.first == action.to_s && line.last == path
    end
    fail "Action #{action.inspect} was not performed on: #{path}"
  end

  def within_tmp_directory(dir = "tmp")
    d = absolutize(dir)
    FileUtils.mkdir_p(d)
    Dir.chdir(d) do
      yield
    end
  ensure
    FileUtils.rm_r(d)
  end

  def capture_output
    real_stdout, $stdout = $stdout, StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = real_stdout
  end

  def execute(*arguments)
    Compass::Exec::Compass.new(arguments).run!
  end

  def generate_rails_app(name)
    `rails #{name}`
  end
end