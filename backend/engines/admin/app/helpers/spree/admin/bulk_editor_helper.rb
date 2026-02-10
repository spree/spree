module Spree
  module Admin
    module BulkEditorHelper
      # Define the cell actions using Stimulus keyboard event filters
      # Note: Enter, Escape, Delete, Backspace are handled via keydown->bulk-editor#handleKeydown
      # since they need special logic for edit mode vs selection mode
      # @return [String] the cell actions
      def bulk_editor_cell_actions
        [
          'focus->bulk-editor#onCellFocus',
          'blur->bulk-editor#onCellBlur',
          'mousedown->bulk-editor#onCellMouseDown',
          'mouseenter->bulk-editor#onCellMouseEnter',
          'dblclick->bulk-editor#onCellDoubleClick',
          'input->bulk-editor#markDirty',
          'keydown->bulk-editor#handleKeydown',
          # Copy/Paste/Fill (Ctrl for Windows/Linux, Meta for Mac)
          'keydown.ctrl+c->bulk-editor#copy',
          'keydown.meta+c->bulk-editor#copy',
          'keydown.ctrl+v->bulk-editor#paste',
          'keydown.meta+v->bulk-editor#paste',
          'keydown.ctrl+d->bulk-editor#fillDown',
          'keydown.meta+d->bulk-editor#fillDown',
          # Navigation (only works in selection mode)
          'keydown.up->bulk-editor#navigateUp',
          'keydown.down->bulk-editor#navigateDown',
          'keydown.left->bulk-editor#navigateLeft',
          'keydown.right->bulk-editor#navigateRight',
          # Selection
          'keydown.shift+up->bulk-editor#selectUp',
          'keydown.shift+down->bulk-editor#selectDown',
          'keydown.shift+left->bulk-editor#selectLeft',
          'keydown.shift+right->bulk-editor#selectRight',
          # Tab navigation (works in both modes)
          'keydown.tab->bulk-editor#navigateRight',
          'keydown.shift+tab->bulk-editor#navigateLeft'
        ].join(' ')
      end
    end
  end
end
