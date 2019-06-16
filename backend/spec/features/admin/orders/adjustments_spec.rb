require 'spec_helper'

describe 'Adjustments', type: :feature do
  stub_authorization!

  let!(:order) { create(:completed_order_with_totals, line_items_count: 5) }
  let!(:line_item) do
    line_item = order.line_items.first
    # so we can be sure of a determinate price in our assertions
    line_item.update_column(:price, 10)
    line_item
  end

  before do
    create(:tax_adjustment,
            adjustable: line_item,
            state: 'closed',
            order: order,
            label: 'VAT 5%',
            amount: 10)

    order.adjustments.create!(order: order, label: 'Rebate', amount: 10)

    # To ensure the order totals are correct
    order.update_totals
    order.persist_totals

    visit spree.admin_orders_path
    within_row(1) { click_on order.number }
    click_on 'Adjustments'
  end

  after do
    order.reload.all_adjustments.each do |adjustment|
      expect(adjustment.order_id).to equal(order.id)
    end
  end

  context 'admin managing adjustments' do
    it 'displays the correct values for existing order adjustments' do
      within_row(1) do
        expect(column_text(2)).to eq('VAT 5%')
        expect(column_text(3)).to eq('$10.00')
      end
    end

    it 'only shows eligible adjustments' do
      expect(page).not_to have_content('ineligible')
    end
  end

  context 'admin creating a new adjustment' do
    before do
      click_link 'New Adjustment'
    end

    context 'successfully' do
      it 'creates a new adjustment' do
        fill_in 'adjustment_amount', with: '10'
        fill_in 'adjustment_label', with: 'rebate'
        click_button 'Continue'
        expect(page).to have_content('successfully created!')
        expect(page).to have_content('Total: $80.00')
      end
    end

    context 'with validation errors' do
      it 'does not create a new adjustment' do
        fill_in 'adjustment_amount', with: ''
        fill_in 'adjustment_label', with: ''
        click_button 'Continue'
        expect(page).to have_content("Label can't be blank")
      end
    end
  end

  context 'admin editing an adjustment', js: true do
    before do
      within_row(2) { click_icon :edit }
    end

    context 'successfully' do
      it 'updates the adjustment' do
        fill_in 'adjustment_amount', with: '99'
        fill_in 'adjustment_label', with: 'rebate 99'
        click_button 'Continue'
        expect(page).to have_content('successfully updated!')
        expect(page).to have_content('rebate 99')
        within('.adjustments') do
          expect(page).to have_content('$99.00')
        end

        expect(page).to have_content('Total: $159.00')
      end
    end

    context 'with validation errors' do
      it 'does not update the adjustment' do
        fill_in 'adjustment_amount', with: ''
        fill_in 'adjustment_label', with: ''
        click_button 'Continue'
        expect(page).to have_content("Label can't be blank")
      end
    end
  end

  context 'deleting an adjustment' do
    it 'updates the total', js: true do
      accept_confirm do
        within_row(2) do
          click_icon(:delete)
        end
      end

      expect(page).to have_content(/Total: ?\$170\.00/)
    end
  end
end
