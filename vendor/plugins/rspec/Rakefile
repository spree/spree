$:.unshift('lib')
require 'rubygems'
require 'rake/gempackagetask'
require 'rake/contrib/rubyforgepublisher'
require 'rake/clean'
require 'rake/rdoctask'
require 'rake/testtask'
require 'spec/version'
dir = File.dirname(__FILE__)
$LOAD_PATH.unshift(File.expand_path("#{dir}/pre_commit/lib"))
require "pre_commit"

# Some of the tasks are in separate files since they are also part of the website documentation
load File.dirname(__FILE__) + '/rake_tasks/examples.rake'
load File.dirname(__FILE__) + '/rake_tasks/examples_with_rcov.rake'
load File.dirname(__FILE__) + '/rake_tasks/failing_examples_with_html.rake'
load File.dirname(__FILE__) + '/rake_tasks/verify_rcov.rake'

PKG_NAME = "rspec"
PKG_VERSION   = Spec::VERSION::STRING
PKG_FILE_NAME = "#{PKG_NAME}-#{PKG_VERSION}"
PKG_FILES = FileList[
  '[A-Z]*',
  'lib/**/*.rb', 
  'spec/**/*',
  'examples/**/*',
  'failing_examples/**/*',
  'plugins/**/*',
  'stories/**/*',
  'pre_commit/**/*',
  'rake_tasks/**/*'
]

task :default => [:verify_rcov]
task :verify_rcov => [:spec, :stories]

desc "Run all specs"
Spec::Rake::SpecTask.new do |t|
  t.spec_files = FileList['spec/**/*_spec.rb']
  t.spec_opts = ['--options', 'spec/spec.opts']
  unless ENV['NO_RCOV']
    t.rcov = true
    t.rcov_dir = '../doc/output/coverage'
    t.rcov_opts = ['--exclude', 'spec\/spec,bin\/spec,examples,\/var\/lib\/gems,\/Library\/Ruby,\.autotest']
  end
end

desc "Run all stories"
task :stories do
  html = 'story_server/prototype/rspec_stories.html'
  ruby "stories/all.rb --colour --format plain --format html:#{html}"
  unless IO.read(html) =~ /<span class="param">/m
    raise 'highlighted parameters are broken in story HTML'
  end
end

desc "Run all specs and store html output in doc/output/report.html"
Spec::Rake::SpecTask.new('spec_html') do |t|
  t.spec_files = FileList['spec/**/*_spec.rb', '../../RSpec.tmbundle/Support/spec/*_spec.rb']
  t.spec_opts = ['--format html:../doc/output/report.html','--backtrace']
end

desc "Run all failing examples"
Spec::Rake::SpecTask.new('failing_examples') do |t|
  t.spec_files = FileList['failing_examples/**/*_spec.rb']
end

desc 'Generate RDoc'
rd = Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_dir = '../doc/output/rdoc'
  rdoc.options << '--title' << 'RSpec' << '--line-numbers' << '--inline-source' << '--main' << 'README'
  rdoc.rdoc_files.include('README', 'CHANGES', 'MIT-LICENSE', 'UPGRADE', 'lib/**/*.rb')
end

spec = Gem::Specification.new do |s|
  s.name = PKG_NAME
  s.version = PKG_VERSION
  s.summary = Spec::VERSION::DESCRIPTION
  s.description = <<-EOF
    RSpec is a behaviour driven development (BDD) framework for Ruby.  RSpec was
    created in response to Dave Astels' article _A New Look at Test Driven Development_
    which can be read at: http://daveastels.com/index.php?p=5  RSpec is intended to
    provide the features discussed in Dave's article.
  EOF

  s.files = PKG_FILES.to_a
  s.require_path = 'lib'

  s.has_rdoc = true
  s.rdoc_options = rd.options
  s.extra_rdoc_files = rd.rdoc_files.reject { |fn| fn =~ /\.rb$|^EXAMPLES.rd$/ }.to_a

  s.bindir = 'bin'
  s.executables = ['spec', 'spec_translator']
  s.default_executable = 'spec'
  s.author = "RSpec Development Team"
  s.email = "rspec-devel@rubyforge.org"
  s.homepage = "http://rspec.rubyforge.org"
  s.platform = Gem::Platform::RUBY
  s.rubyforge_project = "rspec"
end

Rake::GemPackageTask.new(spec) do |pkg|
  pkg.need_zip = true
  pkg.need_tar = true
end

def egrep(pattern)
  Dir['**/*.rb'].each do |fn|
    count = 0
    open(fn) do |f|
      while line = f.gets
        count += 1
        if line =~ pattern
          puts "#{fn}:#{count}:#{line}"
        end
      end
    end
  end
end

desc "Look for TODO and FIXME tags in the code"
task :todo do
  egrep /(FIXME|TODO|TBD)/
end

task :clobber do
  core.clobber
end

task :release => [:clobber, :verify_committed, :verify_user, :spec, :publish_packages, :tag, :publish_news]

desc "Verifies that there is no uncommitted code"
task :verify_committed do
  IO.popen('svn stat') do |io|
    io.each_line do |line|
      raise "\n!!! Do a svn commit first !!!\n\n" if line =~ /^\s*M\s*/
    end
  end
end

desc "Creates a tag in svn"
task :tag do
  from = `svn info #{File.dirname(__FILE__)}`.match(/URL: (.*)\/rspec/n)[1]
  to = from.gsub(/trunk/, "tags/#{Spec::VERSION::TAG}")
  current = from.gsub(/trunk/, "tags/CURRENT")

  puts "Creating tag in SVN"
  tag_cmd = "svn cp #{from} #{to} -m \"Tag release #{Spec::VERSION::FULL_VERSION}\""
  `#{tag_cmd}` ; raise "ERROR: #{tag_cmd}" unless $? == 0

  puts "Removing CURRENT"
  remove_current_cmd = "svn rm #{current} -m \"Remove tags/CURRENT\""
  `#{remove_current_cmd}` ; raise "ERROR: #{remove_current_cmd}" unless $? == 0

  puts "Re-Creating CURRENT"
  create_current_cmd = "svn cp #{to} #{current} -m \"Copy #{Spec::VERSION::TAG} to tags/CURRENT\""
  `#{create_current_cmd}` ; "ERROR: #{create_current_cmd}" unless $? == 0
end

desc "Run this task before you commit. You should see 'OK TO COMMIT'"
task(:pre_commit) {core.pre_commit}

desc "Build the website, but do not publish it"
task(:website) {core.website}

task(:rdoc_rails) {core.rdoc_rails}

task :verify_user do
  raise "RUBYFORGE_USER environment variable not set!" unless ENV['RUBYFORGE_USER']
end

desc "Upload Website to RubyForge"
task :publish_website => [:verify_user, :website] do
  unless Spec::VERSION::RELEASE_CANDIDATE
    publisher = Rake::SshDirPublisher.new(
      "rspec-website@rubyforge.org",
      "/var/www/gforge-projects/#{PKG_NAME}",
      "../doc/output"
    )
    publisher.upload
  else
    puts "** Not publishing packages to RubyForge - this is a prerelease"
  end
end

desc "Upload Website archive to RubyForge"
task :archive_website => [:verify_user, :website] do
  publisher = Rake::SshDirPublisher.new(
    "rspec-website@rubyforge.org",
    "/var/www/gforge-projects/#{PKG_NAME}/#{Spec::VERSION::TAG}",
    "../doc/output"
  )
  publisher.upload
end

desc "Package the Rails plugin"
task :package_rspec_on_rails do
  mkdir 'pkg' rescue nil
  rm_rf 'pkg/rspec_on_rails' rescue nil
  `svn export ../rspec_on_rails pkg/rspec_on_rails-#{PKG_VERSION}`
  Dir.chdir 'pkg' do
    `tar cvzf rspec_on_rails-#{PKG_VERSION}.tgz rspec_on_rails-#{PKG_VERSION}`
  end
end
task :pkg => :package_rspec_on_rails

desc "Package the RSpec.tmbundle"
task :package_tmbundle do
  mkdir 'pkg' rescue nil
  rm_rf 'pkg/RSpec.tmbundle' rescue nil
  `svn export ../RSpec.tmbundle pkg/RSpec.tmbundle`
  Dir.chdir 'pkg' do
    `tar cvzf RSpec-#{PKG_VERSION}.tmbundle.tgz RSpec.tmbundle`
  end
end
task :pkg => :package_tmbundle

desc "Publish gem+tgz+zip on RubyForge. You must make sure lib/version.rb is aligned with the CHANGELOG file"
task :publish_packages => [:verify_user, :package] do
  release_files = FileList[
    "pkg/#{PKG_FILE_NAME}.gem",
    "pkg/#{PKG_FILE_NAME}.tgz",
    "pkg/rspec_on_rails-#{PKG_VERSION}.tgz",
    "pkg/#{PKG_FILE_NAME}.zip",
    "pkg/RSpec-#{PKG_VERSION}.tmbundle.tgz"
  ]
  unless Spec::VERSION::RELEASE_CANDIDATE
    require 'meta_project'
    require 'rake/contrib/xforge'

    Rake::XForge::Release.new(MetaProject::Project::XForge::RubyForge.new(PKG_NAME)) do |xf|
      # Never hardcode user name and password in the Rakefile!
      xf.user_name = ENV['RUBYFORGE_USER']
      xf.files = release_files.to_a
      xf.release_name = "RSpec #{PKG_VERSION}"
    end
  else
    puts "SINCE THIS IS A PRERELEASE, FILES ARE UPLOADED WITH SSH, NOT TO THE RUBYFORGE FILE SECTION"
    puts "YOU MUST TYPE THE PASSWORD #{release_files.length} TIMES..."

    host = "rspec-website@rubyforge.org"
    remote_dir = "/var/www/gforge-projects/#{PKG_NAME}"

    publisher = Rake::SshFilePublisher.new(
      host,
      remote_dir,
      File.dirname(__FILE__),
      *release_files
    )
    publisher.upload

    puts "UPLADED THE FOLLOWING FILES:"
    release_files.each do |file|
      name = file.match(/pkg\/(.*)/)[1]
      puts "* http://rspec.rubyforge.org/#{name}"
    end

    puts "They are not linked to anywhere, so don't forget to tell people!"
  end
end

desc "Publish news on RubyForge"
task :publish_news => [:verify_user] do
  unless Spec::VERSION::RELEASE_CANDIDATE
    require 'meta_project'
    require 'rake/contrib/xforge'
    Rake::XForge::NewsPublisher.new(MetaProject::Project::XForge::RubyForge.new(PKG_NAME)) do |news|
      # Never hardcode user name and password in the Rakefile!
      news.user_name = ENV['RUBYFORGE_USER']
    end
  else
    puts "** Not publishing news to RubyForge - this is a prerelease"
  end
end

def core
  PreCommit::Core.new(self)
end
