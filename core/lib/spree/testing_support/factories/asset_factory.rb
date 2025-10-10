FactoryBot.define do
  factory :asset, class: Spree::Asset do
    viewable_type {}
    viewable_id {}
    attachment_width { 340 }
    attachment_height { 280 }
    attachment_file_size { 128 }
    position { 1 }
    attachment_content_type { '.jpg' }
    attachment_file_name { 'attachment.jpg' }
    type {}
    attachment_updated_at {}
    alt {}
  end
end
