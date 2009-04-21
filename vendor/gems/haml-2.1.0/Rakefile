require 'rubygems'
require 'rake'

# ----- Benchmarking -----

desc <<END
Benchmark haml against ERb.
  TIMES=n sets the number of runs. Defaults to 1000.
END
task :benchmark do
  sh "ruby test/benchmark.rb #{ENV['TIMES']}"
end

# ----- Default: Testing ------

if ENV["RUN_CODE_RUN"] == "true"
  task :default => :"test:rails_compatibility"
else
  task :default => :test
end

require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs << 'lib'
  test_files = FileList['test/**/*_test.rb']
  test_files.exclude('test/rails/*')
  t.test_files = test_files
  t.verbose = true
end
Rake::Task[:test].send(:add_comment, <<END)
To run with an alternate version of Rails, make test/rails a symlink to that version.
END

# ----- Packaging -----

require 'rake/gempackagetask'
load    'haml.gemspec'

Rake::GemPackageTask.new(HAML_GEMSPEC) do |pkg|
  if Rake.application.top_level_tasks.include?('release')
    pkg.need_tar_gz  = true
    pkg.need_tar_bz2 = true
    pkg.need_zip     = true
  end
end

task :revision_file do
  require 'lib/haml'

  if Haml.version[:rev] && !Rake.application.top_level_tasks.include?('release')
    File.open('REVISION', 'w') { |f| f.puts Haml.version[:rev] }
  elsif Rake.application.top_level_tasks.include?('release')
    File.open('REVISION', 'w') { |f| f.puts "(release)" }
  else
    File.open('REVISION', 'w') { |f| f.puts "(unknown)" }
  end
end
Rake::Task[:package].prerequisites.insert(0, :revision_file)

# We also need to get rid of this file after packaging.
at_exit { File.delete('REVISION') rescue nil }

desc "Install Haml as a gem."
task :install => [:package] do
  sudo = RUBY_PLATFORM =~ /win32/ ? '' : 'sudo'
  gem  = RUBY_PLATFORM =~ /java/  ? 'jgem' : 'gem' 
  sh %{#{sudo} #{gem} install --no-ri pkg/haml-#{File.read('VERSION').strip}}
end

desc "Release a new Haml package to Rubyforge. Requires the NAME and VERSION flags."
task :release => [:package] do
  name, version = ENV['NAME'], ENV['VERSION']
  raise "Must supply NAME and VERSION for release task." unless name && version
  sh %{rubyforge login}
  sh %{rubyforge add_release haml haml "#{name} (v#{version})" pkg/haml-#{version}.gem}
  sh %{rubyforge add_file    haml haml "#{name} (v#{version})" pkg/haml-#{version}.tar.gz}
  sh %{rubyforge add_file    haml haml "#{name} (v#{version})" pkg/haml-#{version}.tar.bz2}
  sh %{rubyforge add_file    haml haml "#{name} (v#{version})" pkg/haml-#{version}.zip}
end

# ----- Documentation -----

begin
  require 'hanna/rdoctask'
rescue LoadError
  require 'rake/rdoctask'
end

Rake::RDocTask.new do |rdoc|
  rdoc.title    = 'Haml/Sass'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include(*FileList.new('*') do |list|
                            list.exclude(/(^|[^.a-z])[a-z]+/)
                            list.exclude('TODO')
                          end.to_a)
  rdoc.rdoc_files.include('lib/**/*.rb')
  rdoc.rdoc_files.exclude('TODO')
  rdoc.rdoc_files.exclude('lib/haml/buffer.rb')
  rdoc.rdoc_files.exclude('lib/sass/tree/*')
  rdoc.rdoc_dir = 'rdoc'
  rdoc.main = 'README.rdoc'
end

# ----- Coverage -----

begin
  require 'rcov/rcovtask'

  Rcov::RcovTask.new do |t|
    t.test_files = FileList['test/**/*_test.rb']
    t.rcov_opts << '-x' << '"^\/"'
    if ENV['NON_NATIVE']
      t.rcov_opts << "--no-rcovrt"
    end
    t.verbose = true
  end
rescue LoadError; end

# ----- Profiling -----

begin
  require 'ruby-prof'

  desc <<END
Run a profile of haml.
  ENGINE=str sets the engine to be profiled. Defaults to Haml.
  TIMES=n sets the number of runs. Defaults to 1000.
  FILE=str sets the file to profile.
    Defaults to 'standard' for Haml and 'complex' for Sass.
  OUTPUT=str sets the ruby-prof output format.
    Can be Flat, CallInfo, or Graph. Defaults to Flat. Defaults to Flat.
END
  task :profile do
    engine = (ENV['ENGINE'] || 'haml').downcase
    times  = (ENV['TIMES'] || '1000').to_i
    file   = ENV['FILE']

    if engine == 'sass'
      require 'lib/sass'

      file = File.read("#{File.dirname(__FILE__)}/test/sass/templates/#{file || 'complex'}.sass")
      result = RubyProf.profile { times.times { Sass::Engine.new(file).render } }
    else
      require 'lib/haml'

      file = File.read("#{File.dirname(__FILE__)}/test/haml/templates/#{file || 'standard'}.haml")
      obj = Object.new
      Haml::Engine.new(file).def_method(obj, :render)
      result = RubyProf.profile { times.times { obj.render } }
    end

    RubyProf.const_get("#{(ENV['OUTPUT'] || 'Flat').capitalize}Printer").new(result).print 
  end
rescue LoadError; end

# ----- Testing Multiple Rails Versions -----

rails_versions = [
  "v2.3.0",
  "v2.2.2",
  "v2.1.2",
  "v2.0.5"
]

namespace :test do
  desc "Test all supported versions of rails. This takes a while."
  task :rails_compatibility do
    `rm -rf test/rails`
    puts "Checking out rails. Please wait."
    `git clone git://github.com/rails/rails.git test/rails` rescue nil
    begin
      rails_versions.each do |version|
        Dir.chdir "test/rails" do
          `git checkout #{version}`
        end
        puts "Testing Rails #{version}"
        Rake::Task['test'].reenable
        Rake::Task['test'].execute
      end
    ensure
      `rm -rf test/rails`
    end
  end
end
