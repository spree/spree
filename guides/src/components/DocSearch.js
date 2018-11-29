import * as React from 'react'
import IconSearch from 'react-feather/dist/icons/search'

export default class DocSearch extends React.Component {
  state = {
    enabled: true
  }

  componentDidMount() {
    // Initialize Algolia search.
    if (window.docsearch) {
      window.docsearch({
        apiKey: 'fb697cd2d04591b036ea172259c05ba8',
        indexName: 'spreecommerce',
        inputSelector: '#algolia-doc-search'
      })
    } else {
      console.warn('Search has failed to load and now is being disabled')
      this.setState({ enabled: false })
    }
  }

  render() {
    const { enabled } = this.state

    return enabled ? (
      <form className="ml4 relative">
        <IconSearch className="absolute z-999 top-0 mt2 pt1 ml3 moon-gray" />
        <input
          className="pv3 pr3 w6 br2 ba b--moon-gray"
          id="algolia-doc-search"
          type="search"
          placeholder="Search docs..."
          aria-label="Search docs"
          size="40"
          css={{
            paddingLeft: '3rem'
          }}
        />
      </form>
    ) : null
  }
}
