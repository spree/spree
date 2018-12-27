import * as React from 'react'
import PropTypes from 'prop-types'
import Helmet from 'react-helmet'
import { StaticQuery, graphql } from 'gatsby'
import { cx } from 'emotion'

import Header from './Header'
import Sidebar from './Sidebar'

import styles from '../utils/styles'

import 'tachyons/css/tachyons.css'
import '../styles/app.css'

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
          <React.Fragment>
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
                nav={this.props.nav}
              />
              {this.props.nav && (
                <Sidebar
                  nav={this.props.nav}
                  activeSection={this.props.activeSection}
                />
              )}

              <main
                className={cx(
                  this.props.nav && 'nested-links lh-copy pa4 pl5-l pr4-l pt3'
                )}
                css={{
                  '@media (min-width: 60rem)': {
                    marginLeft: this.props.nav ? styles.sidebar.width : '0'
                  }
                }}
              >
                {this.props.children}
              </main>
            </div>
          </React.Fragment>
        )}
      />
    )
  }
}
