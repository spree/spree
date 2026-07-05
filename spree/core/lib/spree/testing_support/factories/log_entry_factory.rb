FactoryBot.define do
  factory :log_entry, class: Spree::LogEntry do
    source { build(:order) }
    details { 'Some details' }
  end
end
