import { useState } from 'react';
import { View, StyleSheet, ScrollView, Text, Pressable } from 'react-native';
import { EnrichedTextInput } from 'react-native-enriched';
import { Button } from '../components/Button';
import { Toolbar } from '../components/Toolbar';
import { LinkModal } from '../components/LinkModal';
import { MentionPopup } from '../components/MentionPopup';
import { ImageModal } from '../components/ImageModal';
import { ValueModal } from '../components/ValueModal';
import { useEditorState } from '../hooks/useEditorState';
import {
  LINK_REGEX,
  htmlStyle,
  ANDROID_EXPERIMENTAL_SYNCHRONOUS_EVENTS,
} from '../constants/editorConfig';
import {
  INPUT_HTML_EXAMPLES,
  type InputExample,
} from '../constants/inputExamples';

interface TestScreenProps {
  onSwitch: () => void;
  onSwitchEnrichedText: () => void;
}

const DEFAULT_INPUT_EXAMPLE = INPUT_HTML_EXAMPLES[0] as InputExample;

export function TestScreen({
  onSwitch,
  onSwitchEnrichedText,
}: TestScreenProps) {
  const editor = useEditorState();
  const [sizeMode, setSizeMode] = useState<'base' | 'max'>('base');
  const [isExampleDropdownOpen, setIsExampleDropdownOpen] = useState(false);
  const [selectedExampleKey, setSelectedExampleKey] = useState(
    DEFAULT_INPUT_EXAMPLE.key
  );
  const selectedExample =
    INPUT_HTML_EXAMPLES.find((example) => example.key === selectedExampleKey) ??
    DEFAULT_INPUT_EXAMPLE;

  const setExample = (example: InputExample = selectedExample) => {
    setSelectedExampleKey(example.key);
    setIsExampleDropdownOpen(false);
    editor.setValue(example.html);
  };

  return (
    <>
      <ScrollView
        style={styles.container}
        contentContainerStyle={styles.content}
      >
        <View style={styles.buttonStack}>
          <Button
            title="Focus"
            onPress={editor.handleFocus}
            style={styles.button}
            testID="focus-button"
          />
          <Button
            title="Blur"
            onPress={editor.handleBlur}
            style={styles.button}
            testID="blur-button"
          />
          <Button
            title="Clear"
            onPress={editor.handleClear}
            style={styles.button}
            testID="clear-button"
          />
          <Button
            title={sizeMode === 'max' ? 'Base' : 'Max'}
            onPress={() => setSizeMode(sizeMode === 'max' ? 'base' : 'max')}
            style={styles.button}
            testID="size-max-button"
          />
        </View>
        <View style={styles.editor} testID="editor-container">
          <EnrichedTextInput
            ref={editor.ref}
            mentionIndicators={['@', '#']}
            style={
              sizeMode === 'max'
                ? { ...styles.editorInput, ...styles.editorInputMax }
                : styles.editorInput
            }
            htmlStyle={htmlStyle}
            placeholder="Type something here..."
            placeholderTextColor="rgb(0, 26, 114)"
            selectionColor="deepskyblue"
            cursorColor="dodgerblue"
            autoCapitalize="sentences"
            linkRegex={LINK_REGEX}
            onChangeText={(e) => editor.handleChangeText(e.nativeEvent)}
            onChangeHtml={(e) => editor.handleChangeHtml(e.nativeEvent)}
            onChangeState={(e) => editor.handleChangeState(e.nativeEvent)}
            onLinkDetected={editor.handleLinkDetected}
            onStartMention={editor.handleStartMention}
            onChangeMention={editor.handleChangeMention}
            onEndMention={editor.handleEndMention}
            onFocus={editor.handleFocusEvent}
            onBlur={editor.handleBlurEvent}
            onChangeSelection={(e) =>
              editor.handleSelectionChangeEvent(e.nativeEvent)
            }
            onKeyPress={(e) => editor.handleKeyPress(e.nativeEvent)}
            onSubmitEditing={(e) =>
              editor.handleSubmitEditingEvent(e.nativeEvent)
            }
            androidExperimentalSynchronousEvents={
              ANDROID_EXPERIMENTAL_SYNCHRONOUS_EVENTS
            }
            onPasteImages={(e) => editor.handlePasteImagesEvent(e.nativeEvent)}
            useHtmlNormalizer
            testID="editor-input"
          />
          <Toolbar
            stylesState={editor.stylesState}
            editorRef={editor.ref}
            onOpenLinkModal={editor.openLinkModal}
            onSelectImage={editor.openImageModal}
            layout="grid"
          />
        </View>
        <View style={styles.exampleDropdownContainer}>
          <Text style={styles.exampleLabel} testID="input-example-current">
            example: {selectedExample.title}
          </Text>
          <Pressable
            onPress={() => setIsExampleDropdownOpen((isOpen) => !isOpen)}
            style={({ pressed }) => [
              styles.exampleDropdownButton,
              pressed && styles.exampleDropdownButtonPressed,
            ]}
            testID="input-example-dropdown-button"
          >
            <Text style={styles.exampleDropdownButtonText}>
              {selectedExample.title}
            </Text>
            <Text style={styles.exampleDropdownIndicator}>
              {isExampleDropdownOpen ? 'Close' : 'Open'}
            </Text>
          </Pressable>
          {isExampleDropdownOpen && (
            <View
              style={styles.exampleDropdownMenu}
              testID="input-example-dropdown-menu"
            >
              {INPUT_HTML_EXAMPLES.map((example) => {
                const isSelected = example.key === selectedExample.key;

                return (
                  <Pressable
                    key={example.key}
                    onPress={() => setExample(example)}
                    style={({ pressed }) => [
                      styles.exampleDropdownOption,
                      isSelected && styles.exampleDropdownOptionSelected,
                      pressed && styles.exampleDropdownOptionPressed,
                    ]}
                    testID={`input-example-${example.key}-option`}
                  >
                    <Text
                      style={[
                        styles.exampleDropdownOptionText,
                        isSelected && styles.exampleDropdownOptionTextSelected,
                      ]}
                    >
                      {example.title}
                    </Text>
                  </Pressable>
                );
              })}
            </View>
          )}
        </View>
        <View style={styles.buttonRow}>
          <Button
            title="Set Value"
            onPress={editor.openValueModal}
            style={styles.rowButton}
            testID="set-value-button"
          />
          <Button
            title="Set Example"
            onPress={() => setExample()}
            style={styles.rowButton}
            testID="set-example-value-button"
          />
        </View>
        <View style={styles.buttonRow}>
          <Button
            title="Dev Screen"
            onPress={onSwitch}
            style={styles.rowButton}
            testID="toggle-screen-button"
          />
        </View>
        <View style={styles.buttonRow}>
          <Button
            title="Enriched Text Screen"
            onPress={onSwitchEnrichedText}
            style={styles.rowButton}
            testID="toggle-enriched-text-screen-button"
          />
        </View>
      </ScrollView>
      <LinkModal
        avoidKeyboard
        isOpen={editor.isLinkModalOpen}
        editedText={
          editor.insideCurrentLink
            ? editor.currentLink.text
            : (editor.selection?.text ?? '')
        }
        editedUrl={editor.insideCurrentLink ? editor.currentLink.url : ''}
        onSubmit={editor.submitLink}
        onClose={editor.closeLinkModal}
      />
      <ImageModal
        avoidKeyboard
        isOpen={editor.isImageModalOpen}
        onSubmit={editor.selectImage}
        onClose={editor.closeImageModal}
      />
      <ValueModal
        avoidKeyboard
        isOpen={editor.isValueModalOpen}
        onSubmit={editor.submitSetValue}
        onClose={editor.closeValueModal}
      />
      <MentionPopup
        variant="user"
        data={editor.userMention.data}
        isOpen={editor.isUserPopupOpen}
        onItemPress={editor.handleUserMentionSelected}
      />
      <MentionPopup
        variant="channel"
        data={editor.channelMention.data}
        isOpen={editor.isChannelPopupOpen}
        onItemPress={editor.handleChannelMentionSelected}
      />
    </>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: 'white',
  },
  content: {
    flexGrow: 1,
    padding: 16,
    paddingTop: 100,
    alignItems: 'center',
  },
  editor: {
    width: '100%',
  },
  buttonStack: {
    flexDirection: 'row',
    alignItems: 'center',
    width: '100%',
    gap: 8,
  },
  button: {
    flex: 1,
  },
  buttonRow: {
    flexDirection: 'row',
    width: '100%',
    gap: 8,
  },
  rowButton: {
    flex: 1,
  },
  exampleDropdownContainer: {
    width: '100%',
    marginTop: 24,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: 'gray',
    borderRadius: 8,
    padding: 12,
  },
  exampleLabel: {
    color: 'black',
    fontSize: 16,
    fontWeight: '600',
  },
  exampleDropdownButton: {
    marginTop: 8,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: 'gray',
    borderRadius: 8,
    paddingVertical: 12,
    paddingHorizontal: 12,
    backgroundColor: 'white',
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: 12,
  },
  exampleDropdownButtonPressed: {
    opacity: 0.85,
  },
  exampleDropdownButtonText: {
    flex: 1,
    color: 'black',
    fontSize: 16,
    fontWeight: '600',
  },
  exampleDropdownIndicator: {
    color: 'rgb(0, 26, 114)',
    fontSize: 14,
    fontWeight: '700',
  },
  exampleDropdownMenu: {
    marginTop: 8,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: 'gray',
    borderRadius: 8,
    overflow: 'hidden',
  },
  exampleDropdownOption: {
    paddingVertical: 12,
    paddingHorizontal: 12,
    backgroundColor: 'white',
  },
  exampleDropdownOptionSelected: {
    backgroundColor: 'rgba(0, 26, 114, 0.08)',
  },
  exampleDropdownOptionPressed: {
    opacity: 0.85,
  },
  exampleDropdownOptionText: {
    color: 'black',
    fontSize: 16,
  },
  exampleDropdownOptionTextSelected: {
    color: 'rgb(0, 26, 114)',
    fontWeight: '700',
  },
  editorInput: {
    marginTop: 24,
    width: '100%',
    maxHeight: 180,
    backgroundColor: 'gainsboro',
    fontSize: 18,
    fontFamily: 'Nunito-Regular',
    paddingVertical: 12,
    paddingHorizontal: 14,
  },
  editorInputMax: {
    maxHeight: 400,
  },
});
