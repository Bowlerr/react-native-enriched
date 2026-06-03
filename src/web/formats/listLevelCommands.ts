import type { ChainedCommands, Editor } from '@tiptap/core';

function getActiveListItemName(editor: Editor): 'checkboxItem' | 'listItem' {
  return editor.isActive('checkboxItem') ? 'checkboxItem' : 'listItem';
}

function runListLevelCommand(
  editor: Editor,
  apply: (
    chain: ChainedCommands,
    itemName: 'checkboxItem' | 'listItem'
  ) => ChainedCommands
): boolean {
  return apply(editor.chain().focus(), getActiveListItemName(editor)).run();
}

export function increaseWebListLevel(editor: Editor): boolean {
  return runListLevelCommand(editor, (chain, itemName) =>
    chain.sinkListItem(itemName)
  );
}

export function decreaseWebListLevel(editor: Editor): boolean {
  return runListLevelCommand(editor, (chain, itemName) =>
    chain.liftListItem(itemName)
  );
}
