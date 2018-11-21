import * as React from 'react'
import PropTypes from 'prop-types'
import Helmet from 'react-helmet'
import { StaticQuery, graphql } from 'gatsby'

import Header from './Header'
import Sidebar from './Sidebar'

import 'tachyons/css/tachyons.css'

export default class Layout extends React.Component {
  static propTypes = {
    children: PropTypes.node.isRequired,
    nav: PropTypes.array,
    activeSection: PropTypes.string,
    activeRootSection: PropTypes.string
  }

  render() {
    return (
      <StaticQuery
        query={graphql`
          query SiteTitleQuery {
            site {
              siteMetadata {
                title
              }
            }
          }
        `}
        render={data => (
          <>
            <Helmet
              title={data.site.siteMetadata.title}
              meta={[
                { name: 'description', content: 'Sample' },
                { name: 'keywords', content: 'sample, something' }
              ]}
            >
              <html lang="en" />
            </Helmet>
            <div className="sans-serif dark-gray">
              <Header
                siteTitle={data.site.siteMetadata.title}
                activeRootSection={this.props.activeRootSection}
              />
              <div className="mw9 center pa3 flex">
                {this.props.nav && (
                  <div className="w-20 pr2">
                    <Sidebar
                      nav={this.props.nav}
                      activeSection={this.props.activeSection}
                    />
                  </div>
                )}
                <div
                  className={`nested-links ${
                    this.props.nav ? 'w-80 ml3 lh-copy pl4' : 'w-100'
                  }`}
                >
                  {this.props.children}
                </div>
              </div>
            </div>
          </>
        )}
      />
    )
  }
}
