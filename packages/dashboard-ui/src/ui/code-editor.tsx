import {
  autocompletion,
  closeBrackets,
  closeBracketsKeymap,
  completionKeymap,
} from '@codemirror/autocomplete'
import { defaultKeymap, history, historyKeymap, indentWithTab } from '@codemirror/commands'
import { html } from '@codemirror/lang-html'
import { closePercentBrace, liquid } from '@codemirror/lang-liquid'
import {
  bracketMatching,
  defaultHighlightStyle,
  foldGutter,
  indentOnInput,
  syntaxHighlighting,
} from '@codemirror/language'
import { type Diagnostic, lintGutter, setDiagnostics } from '@codemirror/lint'
import { highlightSelectionMatches, searchKeymap } from '@codemirror/search'
import { Compartment, EditorState } from '@codemirror/state'
import {
  drawSelection,
  EditorView,
  highlightActiveLine,
  highlightActiveLineGutter,
  keymap,
  lineNumbers,
} from '@codemirror/view'
import { useEffect, useRef } from 'react'
import { cn } from '../lib/utils'

export interface CodeEditorCompletion {
  /** A variable, or a dotted path to one of its fields (`order.number`). */
  label: string
  /** Short type or value shown next to the label. */
  detail?: string
  /** Longer description shown beside the list. */
  info?: string
}

export interface CodeEditorDiagnostic {
  /** 1-based line the problem is on; problems without one mark the first line. */
  line?: number | null
  message: string
}

export interface CodeEditorProps {
  value: string
  onChange?: (value: string) => void
  /** Variables offered after `{{` and their fields after a dot. */
  completions?: CodeEditorCompletion[]
  /** Filters offered after `|`. */
  filters?: CodeEditorCompletion[]
  diagnostics?: CodeEditorDiagnostic[]
  readOnly?: boolean
  /** Called on Cmd/Ctrl+S. */
  onSave?: () => void
  'aria-label'?: string
  className?: string
}

const theme = EditorView.theme({
  '&': {
    backgroundColor: 'var(--card)',
    color: 'var(--foreground)',
    fontSize: '13px',
    height: '100%',
  },
  '.cm-scroller': { fontFamily: 'var(--font-mono, ui-monospace, monospace)', lineHeight: '1.6' },
  '.cm-content': { caretColor: 'var(--foreground)' },
  '.cm-gutters': {
    backgroundColor: 'var(--background)',
    color: 'var(--muted-foreground)',
    borderRight: '1px solid var(--border)',
  },
  '.cm-activeLine, .cm-activeLineGutter': {
    backgroundColor: 'color-mix(in srgb, var(--accent) 60%, transparent)',
  },
  '&.cm-focused': { outline: 'none' },
  '&.cm-focused .cm-selectionBackground, .cm-selectionBackground': {
    backgroundColor: 'color-mix(in srgb, var(--ring) 20%, transparent)',
  },
  '.cm-tooltip': {
    backgroundColor: 'var(--popover)',
    color: 'var(--popover-foreground)',
    border: '1px solid var(--border)',
    borderRadius: '8px',
  },
})

function toDiagnostics(state: EditorState, problems: CodeEditorDiagnostic[]): Diagnostic[] {
  return problems.map((problem) => {
    const lineNumber = Math.min(Math.max(problem.line ?? 1, 1), state.doc.lines)
    const line = state.doc.line(lineNumber)
    return { from: line.from, to: line.to, severity: 'error', message: problem.message }
  })
}

/**
 * A code editor for Liquid templates written in HTML or MJML, with variable
 * and filter completion, inline problems and the usual editing keys.
 */
function CodeEditor({
  value,
  onChange,
  completions = [],
  filters = [],
  diagnostics = [],
  readOnly = false,
  onSave,
  className,
  ...props
}: CodeEditorProps) {
  const containerRef = useRef<HTMLDivElement>(null)
  const viewRef = useRef<EditorView | null>(null)
  const languageCompartment = useRef(new Compartment())
  const readOnlyCompartment = useRef(new Compartment())
  const callbacks = useRef({ onChange, onSave })
  callbacks.current = { onChange, onSave }

  // biome-ignore lint/correctness/useExhaustiveDependencies: the view is created once; later props flow in through the effects below
  useEffect(() => {
    if (!containerRef.current) return

    const view = new EditorView({
      parent: containerRef.current,
      state: EditorState.create({
        doc: value,
        extensions: [
          lineNumbers(),
          highlightActiveLineGutter(),
          foldGutter(),
          history(),
          drawSelection(),
          indentOnInput(),
          bracketMatching(),
          closeBrackets(),
          closePercentBrace,
          highlightActiveLine(),
          highlightSelectionMatches(),
          autocompletion(),
          lintGutter(),
          syntaxHighlighting(defaultHighlightStyle, { fallback: true }),
          EditorView.lineWrapping,
          theme,
          languageCompartment.current.of([]),
          readOnlyCompartment.current.of(EditorState.readOnly.of(readOnly)),
          keymap.of([
            {
              key: 'Mod-s',
              preventDefault: true,
              run: () => {
                callbacks.current.onSave?.()
                return true
              },
            },
            ...closeBracketsKeymap,
            ...defaultKeymap,
            ...searchKeymap,
            ...historyKeymap,
            ...completionKeymap,
            indentWithTab,
          ]),
          EditorView.updateListener.of((update) => {
            if (update.docChanged) callbacks.current.onChange?.(update.state.doc.toString())
          }),
          EditorView.contentAttributes.of({ 'aria-label': props['aria-label'] ?? '' }),
        ],
      }),
    })
    viewRef.current = view

    return () => {
      view.destroy()
      viewRef.current = null
    }
  }, [])

  useEffect(() => {
    const view = viewRef.current
    if (!view || view.state.doc.toString() === value) return
    view.dispatch({ changes: { from: 0, to: view.state.doc.length, insert: value } })
  }, [value])

  useEffect(() => {
    const variables = completions.filter((completion) => !completion.label.includes('.'))
    const language = liquid({
      base: html(),
      variables,
      filters,
      properties: (path) => {
        const prefix = `${path.join('.')}.`
        return completions
          .filter((completion) => completion.label.startsWith(prefix))
          .map((completion) => ({ ...completion, label: completion.label.slice(prefix.length) }))
          .filter((completion) => !completion.label.includes('.'))
      },
    })
    viewRef.current?.dispatch({ effects: languageCompartment.current.reconfigure(language) })
  }, [completions, filters])

  useEffect(() => {
    viewRef.current?.dispatch({
      effects: readOnlyCompartment.current.reconfigure(EditorState.readOnly.of(readOnly)),
    })
  }, [readOnly])

  useEffect(() => {
    const view = viewRef.current
    if (!view) return
    view.dispatch(setDiagnostics(view.state, toDiagnostics(view.state, diagnostics)))
  }, [diagnostics])

  return (
    <div
      ref={containerRef}
      data-slot="code-editor"
      className={cn(
        'min-h-64 overflow-hidden rounded-md border border-border bg-card shadow-control focus-within:border-blue-500 focus-within:shadow-[0_0_0_3px_color-mix(in_srgb,var(--ring)_15%,transparent)]',
        className,
      )}
    />
  )
}

export { CodeEditor }
