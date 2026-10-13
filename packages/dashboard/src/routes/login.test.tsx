// @vitest-environment happy-dom
import { SpreeError } from '@spree/admin-sdk'
import {
  __resetSlotRegistry,
  LOGIN_AFTER_SLOT,
  type LoginAfterSlotContext,
  registerSlot,
} from '@spree/dashboard-core'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import type { ComponentType } from 'react'
import { act } from 'react'
import { createRoot, type Root } from 'react-dom/client'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

const auth = vi.hoisted(() => ({
  isAuthenticated: false,
  isLoading: false,
  login: vi.fn<(email: string, password: string) => Promise<void>>(),
}))

vi.mock('@spree/dashboard-core', async (importOriginal) => ({
  ...(await importOriginal<typeof import('@spree/dashboard-core')>()),
  useAuth: () => auth,
  adminClient: { auth: { setupStatus: async () => ({ setup_required: false }) } },
}))
vi.mock('@tanstack/react-router', () => ({
  createFileRoute: () => (options: object) => ({ options, useSearch: () => ({}) }),
  Link: ({ children }: { children: React.ReactNode }) => <a href="/">{children}</a>,
  Navigate: () => null,
}))
vi.mock('../hooks/use-auth-providers', () => ({
  authCallbackErrorKey: (code: string) => code,
  useAuthProviders: () => ({
    passwordProvider: { key: 'email', strategy: 'password' },
    redirectProviders: [],
    isLoading: false,
    isError: false,
  }),
}))
vi.mock('../components/spree/auth-shell', () => ({
  AuthShell: ({ children }: { children: React.ReactNode }) => children,
}))

const { Route } = await import('./login')
const LoginPage = Route.options.component as ComponentType

// React 19 only flushes act() updates when the environment opts in.
;(globalThis as { IS_REACT_ACT_ENVIRONMENT?: boolean }).IS_REACT_ACT_ENVIRONMENT = true

let container: HTMLDivElement
let root: Root

function renderLoginPage() {
  container = document.createElement('div')
  document.body.appendChild(container)
  root = createRoot(container)
  act(() =>
    root.render(
      <QueryClientProvider client={new QueryClient()}>
        <LoginPage />
      </QueryClientProvider>,
    ),
  )
}

function fill(id: string, value: string) {
  const input = container.querySelector<HTMLInputElement>(`#${id}`)!
  // Through the prototype setter: React ignores a value assigned on the element itself.
  Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value')!.set!.call(input, value)
  input.dispatchEvent(new Event('input', { bubbles: true }))
}

async function signIn(email: string, password: string) {
  fill('email', email)
  fill('password', password)
  await act(async () => {
    container.querySelector('form')!.requestSubmit()
    // Validation runs asynchronously before the submit handler.
    await new Promise((resolve) => setTimeout(resolve, 0))
  })
}

function slotText() {
  return container.querySelector('[data-testid="login-after"]')?.textContent
}

describe('login page login.after slot', () => {
  beforeEach(() => {
    registerSlot<LoginAfterSlotContext>(LOGIN_AFTER_SLOT, {
      id: 'probe',
      component: ({ error, email }) => (
        <p data-testid="login-after">{`${error?.code ?? 'none'}|${email ?? 'none'}`}</p>
      ),
    })
  })

  afterEach(() => {
    act(() => root.unmount())
    container.remove()
    __resetSlotRegistry()
  })

  it('receives no error or email before a sign-in attempt', () => {
    renderLoginPage()
    expect(slotText()).toBe('none|none')
  })

  it('receives the error and the submitted email after a failed sign-in', async () => {
    auth.login.mockRejectedValueOnce(
      new SpreeError(
        { error: { code: 'email_not_confirmed', message: 'Confirm your email first' } },
        403,
      ),
    )
    renderLoginPage()

    await signIn('new@example.com', 'secret123')

    expect(slotText()).toBe('email_not_confirmed|new@example.com')
    expect(container.textContent).toContain('Confirm your email first')
  })

  it('clears the error when a new attempt starts', async () => {
    let rejectLogin: (error: unknown) => void = () => {}
    auth.login.mockRejectedValueOnce(
      new SpreeError({ error: { code: 'email_not_confirmed', message: 'Confirm' } }, 403),
    )
    renderLoginPage()
    await signIn('new@example.com', 'secret123')

    auth.login.mockImplementationOnce(
      () =>
        new Promise((_resolve, reject) => {
          rejectLogin = reject
        }),
    )
    await signIn('other@example.com', 'secret123')

    expect(slotText()).toBe('none|other@example.com')
    await act(async () => rejectLogin(new TypeError('Failed to fetch')))
    expect(slotText()).toBe('none|other@example.com')
  })
})
