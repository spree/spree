// --- Dependencies
import * as React from 'react'

// --- Components
import Layout from 'components/Layout'
import Section from 'components/Section'
import Button from 'components/base/Button'

// --- Data
import JSONData from '../data/extensions.json'

/**
 * Component
 */

const renderExtension = extension => {
  return (
    <Section path={extension.url} title={extension.name} className="w-50-ns">
      <p>{extension.description}</p>

      <small><Button to={extension.url}>Download</Button></small>
    </Section>
  )
}

export default class ExtensionsPage extends React.Component {
  state = {
    activeCategory: 1
  }

  setActiveLink = id => {
    this.setState({ activeCategory: id })
  }

  render() {
    return (
      <Layout
        title="Extensions"
        description="Spree Commerce API, documentation, guides & tutorials"
        activeRootSection="extensions"
      >
        <div className="center mw9 ph4 mt5 mb4 pb4">
          <h1 className="center tc spree-green">
            Spree Extensions
          </h1>

          <p className="tc mb3">
            Extensions provide additional features and integrations for your Spree store
          </p>

          <nav className="tc center mw8 mb2 pb2 lh-copy">
            {JSONData.categories.map((category, index) => {
              return <a
                      className="link dim black f6 f5-ns dib mr3"
                      href={`#category-${index+1}`}
                      onClick={this.setActiveLink.bind(index+1)}
                     >
                      {category.name}
                    </a>
            })}
          </nav>

          <div className="mw8 center">
            {JSONData.categories.map((category, index) => {
              return (
                <div key={`category_${index}`} id={`category-${index+1}`}>
                  <h2 className="center tc mt4 pt4">{category.name}</h2>
                  <div className="flex flex-column flex-wrap flex-row-ns w-100">
                    {category.extensions.map(extension => renderExtension(extension))}
                  </div>
                </div>
              )
            })}
          </div>

          <p className="tc mt4 pt4">
            If you're an extension author and we didn't list your extension, please
            &nbsp;
            <a href="https://github.com/spree/spree/edit/master/guides/src/data/extensions.json" target="_blank" rel="nofollow" className="fw6 dib link ttu bg-spree-blue pv2 ph3 white br2 lh-copy inline-flex items-center">submit it</a>
          </p>
        </div>
      </Layout>
    )
  }
}
