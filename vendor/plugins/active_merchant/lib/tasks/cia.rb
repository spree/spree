# Figure out the root path of this app. The default method will assume that 
# its the same as the location of the running Rakefile
ROOT = File.expand_path(FileUtils.pwd) + '/'

# Standard settings, you can override each of them using the environment 
# e.g. rake cia EMAIL_TO=your@email.com 
#
RAKE_TASK   = ENV['RAKE_TASK']  || ''
EMAIL_TO    = ENV['EMAIL_TO']   || 'tobi@leetsoft.com'
EMAIL_FROM  = ENV['EMAIL_FROM'] || 'CIA <cia@jadedpixel.com>' 

# Get last segment of application's path and treat it as name. 
NAME        = ENV['NAME'] || ROOT.scan(/(\w+)\/$/).flatten.first.capitalize 


class Build
  attr_reader :status, :output, :success

  def self.run
    Build.new.run
  end
  
  def run 
    update if @status.nil?    
    make if @success.nil?
  end
  
  def revision
    info['Revision'].to_i
  end
  
  def url
    info['URL']
  end
  
  def commit_message
    `svn log #{ROOT} -rHEAD`
  end
  
  def author
    info['Last Changed Author']
  end

  def tests_ok?
    run if @success.nil?
    @success == true
  end
  
  def has_changes?
    update if @status.nil?    
    @status =~ /[A-Z]\s+[\w\/]+/
  end

  private

  def update
    @status = `svn update #{ROOT}`
  end
  
  def info
    @info ||= YAML.load(`svn info #{ROOT}`)
  end
    
  def make
    @output, @success = `cd #{ROOT} && rake #{RAKE_TASK}`, ($?.exitstatus == 0)
  end
end

task :cia do
  build = Build.new
  
  if build.has_changes? and not build.tests_ok? 

    require 'actionmailer'

    ActionMailer::Base.delivery_method = :sendmail

    class Notifier < ActionMailer::Base
      def failure(build, sent_at = Time.now)
        @subject    = "[#{NAME}] Build Failure (##{build.revision})"
        @recipients, @from, @sent_on = EMAIL_TO, EMAIL_FROM, sent_at
        @body       = ["#{build.author} broke the build!", build.commit_message, build.output].join("\n\n")
      end
    end
    
    Notifier.deliver_failure(build)

  end 
end

