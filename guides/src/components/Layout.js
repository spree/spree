// --- Dependencies
import * as React from 'react'
import PropTypes from 'prop-types'
import { cx } from 'emotion'

// --- Components
import Header from 'components/Header'
import Footer from 'components/Footer'
import Sidebar from 'components/Sidebar'
import SiteMetadata from 'components/SiteMetadata'

// --- Utils
import styles from '../utils/styles'

// --- Styles
import 'tachyons/css/tachyons.css'
import '../styles/app.css'

/**
 * Component
 */

export default class Layout extends React.Component {
  static propTypes = {
    children: PropTypes.node.isRequired,
    nav: PropTypes.array,
    activeSection: PropTypes.string,
    activeRootSection: PropTypes.string,
    pathname: PropTypes.string,
    description: PropTypes.string,
    title: PropTypes.string
  }

  render() {
    return (
      <React.Fragment>
        <SiteMetadata
          pathname={this.props.pathname}
          title={this.props.title}
          description={this.props.description}
        />
        <div className="dark-gray">
          <Header
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
              this.props.nav &&
                'bg-white lh-copy pa4 ph5-l pt3 flex flex-column'
            )}
            css={{
              '@media (min-width: 60rem)': {
                marginLeft: this.props.nav ? styles.sidebar.width : '0'
              }
            }}
          >
            {this.props.children}
          </main>
          <Footer hasSidebar={this.props.nav !== undefined} />
        </div>
      </React.Fragment>
    )
  }
}
