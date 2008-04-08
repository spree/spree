require File.dirname(__FILE__) + '/../spec_helper'

describe "script/spec_server file", :shared => true do
  attr_accessor :tmbundle_install_directory

  after do
    system "kill -9 #{@pid}"
  end

  it "runs a spec" do
    dir = File.dirname(__FILE__)
    output = ""
    Timeout.timeout(10) do
      loop do
        output = `#{RAILS_ROOT}/script/spec #{dir}/sample_spec.rb --drb 2>&1`
        break unless output.include?("No server is running")
      end
    end

    unless $?.exitstatus == 0
      flunk "command 'script/spec spec/sample_spec' failed\n#{output}"
    end
  end

  def start_spec_server
    create_spec_server_pid_file
    start_spec_server_process
  end

  def create_spec_server_pid_file
    current_dir = File.dirname(__FILE__)
    pid_dir = "#{Dir.tmpdir}/#{Time.now.to_i}"
    @spec_server_pid_file = "#{pid_dir}/spec_server.pid"
    FileUtils.mkdir_p pid_dir
    system "touch #{@spec_server_pid_file}"
    @rspec_path = File.expand_path("#{current_dir}/../../../rspec/lib")
  end

  def start_spec_server_process
    dir = File.dirname(__FILE__)
    spec_server_cmd =  %Q|export HOME=#{Dir.tmpdir}; |
    spec_server_cmd << %Q|ruby -e 'system("echo " + Process.pid.to_s + " > #{@spec_server_pid_file}"); |
    spec_server_cmd << %Q|$LOAD_PATH.unshift("#{@rspec_path}"); require "spec"; |
    spec_server_cmd << %Q|load "#{RAILS_ROOT}/script/spec_server"' &|
    system spec_server_cmd

    file_content = ""
    Timeout.timeout(5) do
      loop do
        file_content = File.read(@spec_server_pid_file)
        break unless file_content.blank?
      end
    end
    @pid = Integer(File.read(@spec_server_pid_file))
  end
end

describe "script/spec_server file without TextMate bundle" do
  it_should_behave_like "script/spec_server file"
  before do
    start_spec_server
  end
end

describe "script/spec_server file with TextMate bundle" do
  it_should_behave_like "script/spec_server file"
  before do
    dir = File.dirname(__FILE__)
    @tmbundle_install_directory = File.expand_path("#{Dir.tmpdir}/Library/Application Support/TextMate/Bundles")
    @bundle_name = "RSpec.tmbundle"
    FileUtils.mkdir_p(tmbundle_install_directory)
    bundle_dir = File.expand_path("#{dir}/../../../../../../#{@bundle_name}")
    File.directory?(bundle_dir).should be_true
    unless system(%Q|ln -s #{bundle_dir} "#{tmbundle_install_directory}"|)
      raise "Creating link to Textmate Bundle"
    end
    start_spec_server
  end

  after do
    bundle_file_to_remove = "#{tmbundle_install_directory}/#{@bundle_name}"
    if bundle_file_to_remove == "/"
      raise "bundle file path resolved to '/' - could not call rm"
    end
    unless system(%Q|rm "#{bundle_file_to_remove}"|)
      raise "Removing Textmate bundle link failed"
    end
  end
end
