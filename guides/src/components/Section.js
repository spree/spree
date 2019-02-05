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
  <div className={cx('pa4 ba b--light-gray br2 w-50', className)}>
    <h2 className="f3 mt0 spree-blue">
      <Link to={path}>{title}</Link>
    </h2>
    <p className="lh-copy">{children}</p>
  </div>
)

Section.propTypes = {
  title: PropTypes.string.isRequired,
  path: PropTypes.string.isRequired,
  children: PropTypes.node.isRequired,
  className: PropTypes.string
}

export default Section
