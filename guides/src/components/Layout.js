import * as React from 'react'
import PropTypes from 'prop-types'
import Helmet from 'react-helmet'
import { StaticQuery, graphql } from 'gatsby'
import { injectGlobal, cx } from 'emotion'

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
    padding: .15rem .5rem .20rem !important;
  }

  .spree-blue { color: #0066CC }
  .bg-spree-blue { background-color: #0066CC }
  .b--spree-blue { border-color: #0066CC }

  .spree-green { color: #99CC00 }
  .bg-spree-green { background-color: #99CC00 }
  .b--spree-green { border-color: #99CC00 }

  label[role="menuitem"] {
    display: flex;
    align-items: center;
  }

  label[role="menuitem"].active {
    background-color: transparent;
  }

  label[role="menuitem"].active > span {
    color: #99CC00;
  }

  .menu-content {
    border-right: 1px solid #eee;
    padding-top: 1.5rem;
  }

  .menu-content a[target="_blank"]{
    display: none
  }

  .menu-content li > label {
    padding: .5rem 0 .5rem 1rem;
  }

  .menu-content li > label > span {
    font-size: 16px;
    padding-left: 2.5rem;
    color: #0066CC;
    font-weight: 500;
    font-size: 1.15rem;
  }

  .menu-content li > label > svg {
    position: absolute;
    left: 1.5rem;
  }

  .menu-content li > label > span[type] {
    color: #FFF;
    font-weight: 600;
    min-width: 3.5rem;
    font-size: 13px;
    width: auto;
    height: auto;
    padding: .25rem .5rem;
    font-family: 'IBM Plex Mono', monospace !important;
  }

  .menu-content li > ul > li > label > span {
    font-size: 1rem;
    color: #777;
  }
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
                className={cx(
                  this.props.nav && 'nested-links lh-copy pl5 pr4 pt3'
                )}
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
