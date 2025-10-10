require 'rake'

shared_context 'rake' do
  subject         { Rake::Task[task_name] }

  let(:task_name) { self.class.top_level_description }
  let(:task_path) { "lib/tasks/#{task_name.split(':').first}" }

  before do
    Rake::Task.define_task(:environment)
    load File.expand_path(Rails.root + "../../#{task_path}.rake")
    subject.reenable
  end
end
