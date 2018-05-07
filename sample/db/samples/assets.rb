unless ENV['SKIP_SAMPLE_IMAGES']
  Spree::Sample.load_sample('products')
  Spree::Sample.load_sample('variants')
  products = {}
  products[:ror_baseball_jersey] = Spree::Product.find_by!(name: 'Ruby on Rails Baseball Jersey')
  products[:ror_tote] = Spree::Product.find_by!(name: 'Ruby on Rails Tote')
  products[:ror_bag] = Spree::Product.find_by!(name: 'Ruby on Rails Bag')
  products[:ror_jr_spaghetti] = Spree::Product.find_by!(name: 'Ruby on Rails Jr. Spaghetti')
  products[:ror_mug] = Spree::Product.find_by!(name: 'Ruby on Rails Mug')
  products[:ror_ringer] = Spree::Product.find_by!(name: 'Ruby on Rails Ringer T-Shirt')
  products[:ror_stein] = Spree::Product.find_by!(name: 'Ruby on Rails Stein')
  products[:spree_baseball_jersey] = Spree::Product.find_by!(name: 'Spree Baseball Jersey')
  products[:spree_stein] = Spree::Product.find_by!(name: 'Spree Stein')
  products[:spree_jr_spaghetti] = Spree::Product.find_by!(name: 'Spree Jr. Spaghetti')
  products[:spree_mug] = Spree::Product.find_by!(name: 'Spree Mug')
  products[:spree_ringer] = Spree::Product.find_by!(name: 'Spree Ringer T-Shirt')
  products[:spree_tote] = Spree::Product.find_by!(name: 'Spree Tote')
  products[:spree_bag] = Spree::Product.find_by!(name: 'Spree Bag')
  products[:ruby_baseball_jersey] = Spree::Product.find_by!(name: 'Ruby Baseball Jersey')
  products[:apache_baseball_jersey] = Spree::Product.find_by!(name: 'Apache Baseball Jersey')

  def image(name, type = 'jpeg')
    images_path = Pathname.new(File.dirname(__FILE__)) + 'images'
    path = images_path + file_name(name, type)
    return false unless File.exist?(path)
    File.open(path)
  end

  def file_name(name, type = 'jpeg')
    "#{name}.#{type}"
  end

  def attach_paperclip_image(variant, name, type)
    if variant.images.where(attachment_file_name: file_name(name, type)).none?
      image = image(name, type)
      variant.images.create!(attachment: image)
    end
  end

  def attach_active_storage_image(variant, name, type)
    if variant.images.with_attached_attachment.where(active_storage_blobs: { filename: file_name(name, type) }).none?
      image = image(name, type)
      variant.images.create!(attachment: { io: image, filename: file_name(name, type) })
    end
  end

  images = {
    products[:ror_tote].master => [
      {
        name: file_name('ror_tote'),
        attachment: image('ror_tote')
      },
      {
        name: file_name('ror_tote_back'),
        attachment: image('ror_tote_back')
      }
    ],
    products[:ror_bag].master => [
      {
        name: file_name('ror_bag'),
        attachment: image('ror_bag')
      }
    ],
    products[:ror_baseball_jersey].master => [
      {
        name: file_name('ror_baseball'),
        attachment: image('ror_baseball')
      },
      {
        name: file_name('ror_baseball_back'),
        attachment: image('ror_baseball_back')
      }
    ],
    products[:ror_jr_spaghetti].master => [
      {
        name: file_name('ror_jr_spaghetti'),
        attachment: image('ror_jr_spaghetti')
      }
    ],
    products[:ror_mug].master => [
      {
        name: file_name('ror_mug'),
        attachment: image('ror_mug')
      },
      {
        name: file_name('ror_mug_back'),
        attachment: image('ror_mug_back')
      }
    ],
    products[:ror_ringer].master => [
      {
        name: file_name('ror_ringer'),
        attachment: image('ror_ringer')
      },
      {
        name: file_name('ror_ringer_back'),
        attachment: image('ror_ringer_back')
      }
    ],
    products[:ror_stein].master => [
      {
        name: file_name('ror_stein'),
        attachment: image('ror_stein')
      },
      {
        name: file_name('ror_stein_back'),
        attachment: image('ror_stein_back')
      }
    ],
    products[:apache_baseball_jersey].master => [
      {
        name: file_name('apache_baseball', 'png'),
        attachment: image('apache_baseball', 'png')
      }
    ],
    products[:ruby_baseball_jersey].master => [
      {
        name: file_name('ruby_baseball', 'png'),
        attachment: image('ruby_baseball', 'png')
      }
    ],
    products[:spree_bag].master => [
      {
        name: file_name('spree_bag'),
        attachment: image('spree_bag')
      }
    ],
    products[:spree_tote].master => [
      {
        name: file_name('spree_tote_front'),
        attachment: image('spree_tote_front')
      },
      {
        name: file_name('spree_tote_back'),
        attachment: image('spree_tote_back')
      }
    ],
    products[:spree_ringer].master => [
      {
        name: file_name('spree_ringer_t'),
        attachment: image('spree_ringer_t')
      },
      {
        name: file_name('spree_ringer_t_back'),
        attachment: image('spree_ringer_t_back')
      }
    ],
    products[:spree_jr_spaghetti].master => [
      {
        name: file_name('spree_spaghetti'),
        attachment: image('spree_spaghetti')
      }
    ],
    products[:spree_baseball_jersey].master => [
      {
        name: file_name('spree_jersey'),
        attachment: image('spree_jersey')
      },
      {
        name: file_name('spree_jersey_back'),
        attachment: image('spree_jersey_back')
      }
    ],
    products[:spree_stein].master => [
      {
        name: file_name('spree_stein'),
        attachment: image('spree_stein')
      },
      {
        name: file_name('spree_stein_back'),
        attachment: image('spree_stein_back')
      }
    ],
    products[:spree_mug].master => [
      {
        name: file_name('spree_mug'),
        attachment: image('spree_mug')
      },
      {
        name: file_name('spree_mug_back'),
        attachment: image('spree_mug_back')
      }
    ]
  }

  products[:ror_baseball_jersey].variants.each do |variant|
    color = variant.option_value('tshirt-color').downcase

    if Rails.application.config.use_paperclip
      attach_paperclip_image(variant, "ror_baseball_jersey_#{color}", 'png')
      attach_paperclip_image(variant, "ror_baseball_jersey_back_#{color}", 'png')
    else
      attach_active_storage_image(variant, "ror_baseball_jersey_#{color}", 'png')
      attach_active_storage_image(variant, "ror_baseball_jersey_back_#{color}", 'png')
    end
  end

  images.each do |variant, attachments|
    puts "Loading images for #{variant.product.name}"
    attachments.each do |attrs|
      if Rails.application.config.use_paperclip
        file_name = attrs.delete(:name)
        variant.images.create!(attrs) if variant.images.where(attachment_file_name: file_name).none?
      else
        name, type = attrs.delete(:name).split('.')
        attach_active_storage_image(variant, name, type)
      end
    end
  end
end
