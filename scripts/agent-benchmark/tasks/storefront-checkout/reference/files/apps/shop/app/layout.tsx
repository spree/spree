import type { ReactNode } from 'react'

export const metadata = { title: 'Shop' }

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body
        style={{
          fontFamily: 'system-ui, sans-serif',
          maxWidth: 720,
          margin: '0 auto',
          padding: 16,
        }}
      >
        <nav style={{ display: 'flex', gap: 16, marginBottom: 24 }}>
          <a href="/">Products</a>
          <a href="/cart">Cart</a>
        </nav>
        {children}
      </body>
    </html>
  )
}
