// --- Dependencies
import * as React from 'react'
import PropTypes from 'prop-types'
import { cx } from 'emotion'

// --- Components
import Button from 'components/base/Button'

// --- Icons
import { ArrowRight } from 'react-feather'

/**
 * Component
 */

const Section = ({ title, path, children, className }) => (
  <div className={cx('pa4 ba b--light-gray br2 w-50', className)}>
    <h2 className="f3 mt0 spree-blue">{title}</h2>
    <p className="lh-copy pl4">{children}</p>
    <div className="tr mt4">
      <Button to={path}>
        <ArrowRight className="mr1" height={16} /> Read More...
      </Button>
    </div>
  </div>
)

Section.propTypes = {
  title: PropTypes.string.isRequired,
  path: PropTypes.string.isRequired,
  children: PropTypes.node.isRequired,
  className: PropTypes.string
}

export default Section
