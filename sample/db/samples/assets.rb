Spree::Sample.load_sample("products")
Spree::Sample.load_sample("variants")

products = {}
products[:ror_baseball_jersey] = Spree::Product.find_by_name!("Ruby on Rails Baseball Jersey") 
products[:ror_tote] = Spree::Product.find_by_name!("Ruby on Rails Tote")
products[:ror_bag] = Spree::Product.find_by_name!("Ruby on Rails Bag")
products[:ror_jr_spaghetti] = Spree::Product.find_by_name!("Ruby on Rails Jr. Spaghetti")
products[:ror_mug] = Spree::Product.find_by_name!("Ruby on Rails Mug")
products[:ror_ringer] = Spree::Product.find_by_name!("Ruby on Rails Ringer T-Shirt")
products[:ror_stein] = Spree::Product.find_by_name!("Ruby on Rails Stein")
products[:spree_baseball_jersey] = Spree::Product.find_by_name!("Spree Baseball Jersey")
products[:spree_stein] = Spree::Product.find_by_name!("Spree Stein")
products[:spree_jr_spaghetti] = Spree::Product.find_by_name!("Spree Jr. Spaghetti")
products[:spree_mug] = Spree::Product.find_by_name!("Spree Mug")
products[:spree_ringer] = Spree::Product.find_by_name!("Spree Ringer T-Shirt")
products[:spree_tote] = Spree::Product.find_by_name!("Spree Tote")
products[:spree_bag] = Spree::Product.find_by_name!("Spree Bag")
products[:ruby_baseball_jersey] = Spree::Product.find_by_name!("Ruby Baseball Jersey")
products[:apache_baseball_jersey] = Spree::Product.find_by_name!("Apache Baseball Jersey")


def image(name, type="jpeg")
  images_path = Pathname.new(File.dirname(__FILE__)) + "images"
  path = images_path + "#{name}.#{type}"
  return false if !File.exist?(path)
  File.open(path)
end

images = {
  products[:ror_tote].master => [
    {
      :attachment => image("ror_tote")
    },
    {
      :attachment => image("ror_tote_back") 
    }
  ],
  products[:ror_bag].master => [
    {
      :attachment => image("ror_bag")
    }
  ],
  products[:ror_baseball_jersey].master => [
    {
      :attachment => image("ror_baseball")
    },
    {
      :attachment => image("ror_baseball_back")
    }
  ],
  products[:ror_jr_spaghetti].master => [
    {
      :attachment => image("ror_jr_spaghetti")
    }
  ],
  products[:ror_mug].master => [
    {
      :attachment => image("ror_mug")
    },
    {
      :attachment => image("ror_mug_back")
    }
  ],
  products[:ror_ringer].master => [
    {
      :attachment => image("ror_ringer")
    },
    {
      :attachment => image("ror_ringer_back")
    }
  ],
  products[:ror_stein].master => [
    {
      :attachment => image("ror_stein")
    },
    {
      :attachment => image("ror_stein_back")
    }
  ],
  products[:apache_baseball_jersey].master => [
    {
      :attachment => image("apache_baseball", "png")
    },
  ],
  products[:ruby_baseball_jersey].master => [
    {
      :attachment => image("ruby_baseball", "png")
    },
  ],
  products[:spree_bag].master => [
    {
      :attachment => image("spree_bag")
    },
  ],
  products[:spree_tote].master => [
    {
      :attachment => image("spree_tote_front")
    },
    {
      :attachment => image("spree_tote_back") 
    }
  ],
  products[:spree_ringer].master => [
    {
      :attachment => image("spree_ringer_t")
    },
    {
      :attachment => image("spree_ringer_t_back") 
    }
  ],
  products[:spree_jr_spaghetti].master => [
    {
      :attachment => image("spree_spaghetti")
    }
  ],
  products[:spree_baseball_jersey].master => [
    {
      :attachment => image("spree_jersey")
    },
    {
      :attachment => image("spree_jersey_back") 
    }
  ],
  products[:spree_stein].master => [
    {
      :attachment => image("spree_stein")
    },
    {
      :attachment => image("spree_stein_back") 
    }
  ],
  products[:spree_mug].master => [
    {
      :attachment => image("spree_mug")
    },
    {
      :attachment => image("spree_mug_back") 
    }
  ],
}

products[:ror_baseball_jersey].variants.each do |variant|
  color = variant.option_value("tshirt-color").downcase
  main_image = image("ror_baseball_jersey_#{color}", "png")
  variant.images.create!(:attachment => main_image)
  back_image = image("ror_baseball_jersey_back_#{color}", "png")
  if back_image
    variant.images.create!(:attachment => back_image)
  end
end

images.each do |variant, attachments|
  puts "Loading images for #{variant.name}"
  attachments.each do |attachment|
    variant.images.create!(attachment)
  end
end

