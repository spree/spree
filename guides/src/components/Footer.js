// --- Dependencies
import * as React from 'react'
import { cx } from 'emotion'

// --- Images
import LogoSrc from '../images/logo-spark-footer.svg'

// --- Utils
import styles from '../utils/styles'

/**
 * Helpers
 */

const getYear = () => {
  const date = new Date()

  return date.getFullYear()
}

/**
 * Component
 */

const Footer = ({ hasSidebar }) => (
  <footer
    css={{
      '@media (min-width: 60rem)': {
        marginLeft: hasSidebar ? styles.sidebar.width : 'auto'
      }
    }}
    className={cx(
      {
        'mw9 center w-100': !hasSidebar,
        'bt b--light-gray': hasSidebar
      },
      'tc pv3 flex flex-column flex-row-l items-center justify-center lh-copy'
    )}
  >
    <span>Designed and developed by</span>
    <a
      className="inline-flex"
      href="https://sparksolutions.co/"
      target="_blank"
      rel="follow"
    >
      <img
        src={LogoSrc}
        height={21}
        className="dib mh2"
        alt="Spree Commerce & Ruby on Rails developers"
        title="Spree Commerce & Ruby on Rails developers"
      />
    </a>
    <span className="pl2-l bl-l b--light-silver">
      ©{' '}
      <a
        className="link spree-blue hover-spree-green"
        href="https://spreecommerce.org"
        target="_blank"
        rel="follow"
      >
        Spree Commerce.
      </a>{' '}
      {getYear()} All Rights Reserved.
    </span>
  </footer>
)

export default Footer
