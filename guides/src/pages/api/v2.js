import * as React from 'react'
import { RedocStandalone } from 'redoc'

import Layout from '../../components/Layout'

const IndexPage = () => (
  <Layout activeRootSection="api/v2">
    <RedocStandalone
      specUrl="https://raw.githubusercontent.com/spark-solutions/spree/master/api/docs/v2/storefront/index.yaml"
      options={{
        scrollYOffset: 80,
        hideDownloadButton: true,
        theme: {
          colors: {
            primary: {
              main: '#0066CC'
            }
          },
          typography: {
            fontSize: '16px',
            fontFamily: '"IBM Plex Sans", sans-serif;',
            headings: {
              fontFamily: '"IBM Plex Sans", sans-serif;'
            },
            code: {
              fontSize: '14px',
              fontFamily: '"IBM Plex Mono", monospace;',
              fontWeight: 600,
              backgroundColor: '#0066CC',
              color: '#FFF'
            }
          },
          rightPanel: {
            backgroundColor: '#444'
          },
          menu: {
            width: '19rem',
            backgroundColor: '#FFF'
          }
        }
      }}
    />
  </Layout>
)

export default IndexPage
