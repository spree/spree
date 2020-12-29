// --- Dependencies
import * as React from 'react'
import PropTypes from 'prop-types'
import { cx } from 'emotion'

// --- Components
import { Link } from 'gatsby'

/**
 * Component
 */

const Section = ({ title, path, children, className }) => (
  <div className={cx('pa0 pa2-ns flex w-100 mb4 mb0-ns', className)}>
    <div className="ba b--light-gray br2 pa3 w-100">
      <h2 className="f3 mt0 spree-blue">
        {path ? (
          <Link to={path} className="link spree-blue">
            {title}
          </Link>
        ) : (
          title
        )}
      </h2>
      <p className="lh-copy">{children}</p>
    </div>
  </div>
)

Section.propTypes = {
  title: PropTypes.string.isRequired,
  path: PropTypes.string,
  children: PropTypes.node.isRequired,
  className: PropTypes.string
}

export default Section
