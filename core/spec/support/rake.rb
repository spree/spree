require "rake"

shared_context "rake" do
  let(:task_name) { self.class.top_level_description }
  let(:task_path) { "lib/tasks/#{task_name.split(":").first}" }
  subject         { Rake::Task[task_name] }

  before do
    Rake::Task.define_task(:environment)
    load File.expand_path(Rails.root + "../../#{task_path}.rake")
    subject.reenable
  end
end
