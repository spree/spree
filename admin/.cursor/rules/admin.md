# Spree Admin Interface Rules

## Controller Standards
- Admin controllers inherit from `Spree::Admin::ResourceController`
- ResourceController handles most CRUD operations automatically
- Use `stub_authorization!` for controller spec authentication
- Always add `render_views` to controller specs

```ruby
# ✅ Proper admin controller
class Spree::Admin::ProductsController < Spree::Admin::ResourceController
  private

  def permitted_resource_params
    params.require(:product).permit(Spree::PermittedAttributes.product_attributes)
  end
end
```

## Form Builder Standards
- Use `Spree::Admin::FormBuilder` methods for all form fields
- Always use the provided form field methods for consistency

### Available Form Field Methods
- `f.spree_text_field :name`
- `f.spree_number_field :price`
- `f.spree_email_field :email`
- `f.spree_date_field :available_on`
- `f.spree_datetime_field :discontinue_on`
- `f.spree_text_area :description`
- `f.spree_rich_text_area :description` (with Trix editor)
- `f.spree_select :category_id, options`
- `f.spree_collection_select :category_id, collection, :id, :name`
- `f.spree_check_box :active`
- `f.spree_radio_button :status, 'active'`

### Form Structure Standards
For new resource forms:
```erb
<%= render 'spree/admin/shared/new_resource' %>
```

For edit resource forms:
```erb
<%= render 'spree/admin/shared/edit_resource' %>
```

### Reusable Form Partial Pattern
Create `_form.html.erb` with proper card structure:
```erb
<div class="card mb-4">
  <div class="card-header">
    <h5 class="card-title">
      <%= Spree.t(:general_settings) %>
    </h5>
  </div>

  <div class="card-body">
    <%= f.spree_text_field :name %>
    <%= f.spree_rich_text_area :description %>
    <%= f.spree_check_box :active %>
  </div>
</div>
```

## View Standards
- Use Turbo Rails features (Hotwire) as much as possible
- Use Stimulus controllers for JavaScript interactions
- Follow Bootstrap 4 styling conventions
- Use `Spree.t` for all translations

## JavaScript & Stimulus
- Place Stimulus controllers in `app/javascript/controllers/spree/admin/`
- Use data attributes for controller binding
- Follow Stimulus naming conventions

## Asset Organization
- Stylesheets: `app/assets/stylesheets/spree/admin/`
- JavaScript: `app/javascript/`
- Images: `app/assets/images/spree/admin/`

## Security
- Admin controllers are automatically secured when inheriting from ResourceController
- Use CanCanCan for authorization
- Authentication handled by app developers (Devise installer provided)

## Translation Files
- Place admin translations in `admin/config/locales/en.yml`
- Use namespace structure: `spree.admin.product.name`
- Reuse existing translations when possible

## Testing Standards
- Place admin specs in `spec/controllers/spree/admin/`
- Always use `render_views` in controller specs
- Use `stub_authorization!` for authentication in specs

```ruby
# ✅ Proper admin controller spec
require 'spec_helper'

RSpec.describe Spree::Admin::ProductsController, type: :controller do
  stub_authorization!
  render_views
  
  describe '#index' do
    it 'renders the index template' do
      get :index
      expect(response).to render_template(:index)
    end
  end
end
```
