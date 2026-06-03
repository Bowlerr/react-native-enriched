import type { ChainedCommands, Editor } from '@tiptap/core';

import {
  decreaseWebListLevel,
  increaseWebListLevel,
} from '../listLevelCommands';

function createEditorMock({
  checkboxActive = false,
  runResult = true,
}: {
  checkboxActive?: boolean;
  runResult?: boolean;
}) {
  const calls: string[] = [];
  const chain = {
    focus: jest.fn(() => chain),
    sinkListItem: jest.fn((itemName: string) => {
      calls.push(`sink:${itemName}`);
      return chain;
    }),
    liftListItem: jest.fn((itemName: string) => {
      calls.push(`lift:${itemName}`);
      return chain;
    }),
    run: jest.fn(() => runResult),
  } as unknown as ChainedCommands;

  const editor = {
    isActive: jest.fn(
      (name: string) => name === 'checkboxItem' && checkboxActive
    ),
    chain: jest.fn(() => chain),
  } as unknown as Editor;

  return { calls, chain, editor };
}

describe('web list level commands', () => {
  it('indents regular list items', () => {
    const { calls, chain, editor } = createEditorMock({});

    expect(increaseWebListLevel(editor)).toBe(true);

    expect(editor.chain).toHaveBeenCalledTimes(1);
    expect(chain.focus).toHaveBeenCalledTimes(1);
    expect(calls).toEqual(['sink:listItem']);
  });

  it('outdents regular list items', () => {
    const { calls, editor } = createEditorMock({});

    expect(decreaseWebListLevel(editor)).toBe(true);

    expect(calls).toEqual(['lift:listItem']);
  });

  it('uses checkbox list item commands for checkbox selections', () => {
    const { calls, editor } = createEditorMock({ checkboxActive: true });

    increaseWebListLevel(editor);
    decreaseWebListLevel(editor);

    expect(calls).toEqual(['sink:checkboxItem', 'lift:checkboxItem']);
  });

  it('returns the command result for non-list selections', () => {
    const { calls, editor } = createEditorMock({ runResult: false });

    expect(increaseWebListLevel(editor)).toBe(false);

    expect(calls).toEqual(['sink:listItem']);
  });
});
