$:.unshift(File.expand_path('./lib', ENV['rvm_path'])) # Add RVM's lib directory to the load path.
require "rvm/capistrano"                  # Load RVM's capistrano plugin.
require "bundler/capistrano"

set :application, (exists?(:edge) ? "edge-guides" : "guides")
set :user, 'spree'
set :group, 'www-data'
set :domain, 'spree.spreeworks.com'

set :rvm_ruby_string, 'ruby-1.9.2-p290'

set :scm, :git

role :web, domain
role :app, domain
role :db,  domain, :primary => true

set :repository,  "git://github.com/spree/spree-guides.git"
set :branch,      "refactor"
set :deploy_to,   "/data/#{application}"
set :deploy_via,  :remote_cache
set :use_sudo,    false

default_run_options[:pty] = true
set :ssh_options, { :forward_agent => true }

namespace :deploy do
  desc "Builds static html for guides"
  task :build_guides do
    cmd = "cd #{release_path} && bundle exec guides build --clean --ga"
    if exists?(:edge)
      cmd << " --edge"
    end
    run cmd
  end
end

after 'deploy:update_code', 'deploy:build_guides'
