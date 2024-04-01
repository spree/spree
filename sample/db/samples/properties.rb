properties = {
  бренд: 'Бренд',
  модель: 'Модель',
  виробник: 'Виробник',
  зроблено_з: 'Зроблено з',
  формат: 'Формат',
  стать: 'Стать',
  тип: 'Тип',
  розмір: 'Розмір',
  матеріал: 'Матеріал',
  довжина: 'Довжина',
  колір: 'Колір',
  колекція: 'Колекція'
}

properties.each do |name, presentation|
  unless Spree::Property.where(name: name, presentation: presentation).exists?
    Spree::Property.create!(name: name, presentation: presentation)
  end
end

Spree::Property.where(name: %w[бренд виробник]).update(filterable: true)
