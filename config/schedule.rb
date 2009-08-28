# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# Example:
#
# set :cron_log, "/path/to/my/cron_log.log"
#

#
every 5.minutes do
  runner "MailQueue.process"
end

# add a hook in your deploy file to update the cron after each deploy
# config/deploy.rb
# after "deploy:symlink", "deploy:update_crontab"
# 
# namespace :deploy do
#   desc "Update the crontab file"
#   task :update_crontab, :roles => :db do
#     run "cd #{release_path} && whenever --update-crontab #{application}"
#   end
# end

# Learn more: http://github.com/javan/whenever
