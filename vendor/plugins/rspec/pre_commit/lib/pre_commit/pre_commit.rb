class PreCommit
  attr_reader :actor
  def initialize(actor)
    @actor = actor
  end

  protected
  def rake_invoke(task_name)
    Rake::Task[task_name].invoke
  end

  def rake_sh(task_name, env_hash={})
    env = env_hash.collect{|key, value| "#{key}=#{value}"}.join(' ')
    rake = (PLATFORM == "i386-mswin32") ? "rake.bat" : "rake"
    cmd = "#{rake} #{task_name} #{env} --trace"
    output = silent_sh(cmd)
    puts output
    if shell_error?(output)
      raise "ERROR while running rake: #{cmd}"
    end
  end

  def silent_sh(cmd, &block)
    output = nil
    IO.popen(cmd) do |io|
      output = io.read
      output.each_line do |line|
        block.call(line) if block
      end
    end
    output
  end

  def shell_error?(output)
    output =~ /ERROR/n || error_code?
  end

  def error_code?
    $?.exitstatus != 0
  end

  def root_dir
    dir = File.dirname(__FILE__)
    File.expand_path("#{dir}/../../../..")
  end  

  def method_missing(method_name, *args, &block)
    if actor.respond_to?(method_name)
      actor.send(method_name, *args, &block)
    else
      super
    end
  end
end
