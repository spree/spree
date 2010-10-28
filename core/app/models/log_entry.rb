class LogEntry < ActiveRecord::Base
  belongs_to :source, :polymorphic => true
end
