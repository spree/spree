import * as React from 'react'
import PropTypes from 'prop-types'
import Helmet from 'react-helmet'
import { StaticQuery, graphql } from 'gatsby'
import { injectGlobal } from 'emotion'

import Header from './Header'
import Sidebar from './Sidebar'

import styles from '../utils/styles'

import 'tachyons/css/tachyons.css'

injectGlobal`
  body {
    font-family: 'IBM Plex Sans', sans-serif;
  }

  code,
  pre,
  .code {
    font-family: 'IBM Plex Mono', monospace !important;
  }

  p > code,
  li > code {
    font-size: .825rem;
    padding: .10rem .25rem !important;
  }

  .spree-blue { color: #0066CC }
  .bg-spree-blue { background-color: #0066CC }
  .b--spree-blue { border-color: #0066CC }

  .spree-green { color: #99CC00 }
  .bg-spree-green { background-color: #99CC00 }
  .b--spree-green { border-color: #99CC00 }
`

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
            <div className="dark-gray">
              <Header
                siteTitle={data.site.siteMetadata.title}
                activeRootSection={this.props.activeRootSection}
              />
              {this.props.nav && (
                <Sidebar
                  nav={this.props.nav}
                  activeSection={this.props.activeSection}
                />
              )}

              <div
                className="nested-links lh-copy pl5 pr4 pt3"
                css={{
                  marginLeft: this.props.nav ? styles.sidebar.width : '0',
                  marginTop: styles.header.height
                }}
              >
                {this.props.children}
              </div>
            </div>
          </>
        )}
      />
    )
  }
}
