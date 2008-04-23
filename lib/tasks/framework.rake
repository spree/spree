# Only define freeze and unfreeze tasks in instance mode
#unless File.directory? "#{RAILS_ROOT}/app"
  namespace :spree do
    namespace :freeze do
      desc "Lock this application to the current gems (by unpacking them into vendor/spree)"
      task :gems do
        require 'rubygems'
        require 'rubygems/gem_runner'
        Gem.manage_gems

        spree = (version = ENV['VERSION']) ?
          Gem.cache.search('spreee', "= #{version}").first :
          Gem.cache.search('spree').sort_by { |g| g.version }.last

        version ||= spree.version

        unless spree
          puts "No Spree gem #{version} is installed.  Do 'gem list spree' to see what you have available."
          exit
        end

        puts "Freezing to the gems for Spree #{spree.version}"
        rm_rf   "vendor/spree"

        chdir("vendor") do
          Gem::GemRunner.new.run(["unpack", "spree", "--version", "=#{version}"])
          FileUtils.mv(Dir.glob("spree*").first, "spree")
        end
      end
    end

    # TODO - Support freeze from "edge"

    desc "Unlock this application from freeze of gems or edge and return to a fluid use of system gems"
    task :unfreeze do
      rm_rf "vendor/spree"
    end
    
    # TODO - Deal with updating javascript, etc.
  end
#end