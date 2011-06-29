namespace :spree_core do
  task_warning = "[WARNING] This task has been removed, please run Rails default task: rake railties:install:migrations"
  task :install do
    puts task_warning
  end

  namespace :install do

    task :migrations do
      puts task_warning
    end

    task :assets do
      puts "[WARNING] This task is no longer required, and has been replaced with standard Rails 3.1 asset pipeline" 
    end

  end
end
