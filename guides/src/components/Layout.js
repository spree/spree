import * as React from 'react'
import PropTypes from 'prop-types'
import Helmet from 'react-helmet'
import { StaticQuery, graphql } from 'gatsby'

import Header from './Header'
import Sidebar from './Sidebar'

import 'tachyons/css/tachyons.css'

const Layout = ({ children, nav }) => (
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
          <Header siteTitle={data.site.siteMetadata.title} />
          <div className="mw9 center pa3 flex">
            {nav && (
              <div className="w-20">
                <Sidebar nav={nav} />
              </div>
            )}
            <div className={nav ? 'w-80' : 'w-100'}>{children}</div>
          </div>
        </div>
      </>
    )}
  />
)

Layout.propTypes = {
  children: PropTypes.node.isRequired,
  nav: PropTypes.array
}

export default Layout
