import { Controller } from '@hotwired/stimulus'
import { initializeFlatfile } from '@flatfile/javascript'

// import createSubmitDataListener from 'spree/admin/helpers/flatfile/create_submit_data_listener'
import { productsWorkbook } from 'spree/admin/helpers/flatfile/products_workbook'
import { customersWorkbook } from 'spree/admin/helpers/flatfile/customers_workbook'
import { postsWorkbook } from 'spree/admin/helpers/flatfile/posts_workbook'

export default class extends Controller {
  static values = {
    publishableKey: { type: String },
    environmentId: { type: String },
    kind: { type: String, default: 'products' },
    productsPropertiesCount: { type: Number, default: 10 }
  }

  open(event) {
    event.preventDefault()

    const flatfileOptions = {
      name: `Import ${this.kindValue}`,
      publishableKey: this.publishableKeyValue,
      environmentId: this.environmentIdValue,
      workbook: this.workbook,
      listener: createSubmitDataListener(this.kindValue),
      sidebarConfig: {
        showSidebar: false
      }
    }

    initializeFlatfile(flatfileOptions)
  }

  get workbook() {
    switch (this.kindValue) {
      case 'products':
        return productsWorkbook(this.productsPropertiesCountValue)
      case 'customers':
        return customersWorkbook
      case 'posts':
        return postsWorkbook
      default:
        return productsWorkbook
    }
  }
}
