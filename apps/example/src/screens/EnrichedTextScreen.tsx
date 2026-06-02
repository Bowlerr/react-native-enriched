import { useState } from 'react';
import { View, StyleSheet, ScrollView, Text } from 'react-native';
import {
  EnrichedText,
  type EnrichedTextProps,
  type OnLinkPressEvent,
  type OnMentionPressEvent,
} from 'react-native-enriched';
import { Button } from '../components/Button';
import { ValueModal } from '../components/ValueModal';
import { enrichedTextHtmlStyle } from '../constants/editorConfig';
import { STRESS_TEST_HTML } from '../constants/stressTestHtml';
import {
  TEXT_VIEWER_HTML_EXAMPLES,
  type TextViewerExample,
} from '../constants/textViewerExamples';

type EllipsizeMode = EnrichedTextProps['ellipsizeMode'];

interface EnrichedTextScreenProps {
  onSwitch: () => void;
}

export function EnrichedTextScreen({ onSwitch }: EnrichedTextScreenProps) {
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [html, setHtml] = useState<string | null>(null);
  const [activeExampleKey, setActiveExampleKey] = useState<string | null>(null);
  const [rendererRevision, setRendererRevision] = useState(0);
  const [ellipsizeMode, setEllipsizeMode] = useState<EllipsizeMode>('tail');
  const [numberOfLines, setNumberOfLines] = useState<number>(0);

  const applyHtml = (value: string, exampleKey: string | null) => {
    setHtml(value);
    setActiveExampleKey(exampleKey);
    setRendererRevision((revision) => revision + 1);
  };

  const handleSubmit = (value: string) => {
    applyHtml(value, null);
    setIsModalOpen(false);
  };

  const setExample = (example: TextViewerExample) => {
    applyHtml(example.html, example.key);
  };

  const handleLinkPress = (e: OnLinkPressEvent) => {
    applyHtml(`You pressed the link: ${e.url}`, null);
  };

  const handleMentionPress = (e: OnMentionPressEvent) => {
    applyHtml(
      `You pressed the mention: text: ${e.text}, type: ${e.indicator}, attributes: ${JSON.stringify(e.attributes)}`,
      null
    );
  };

  return (
    <>
      <ScrollView
        style={styles.container}
        contentContainerStyle={styles.content}
      >
        <View style={styles.buttonRow}>
          <Button
            title="Test Screen"
            onPress={onSwitch}
            style={styles.rowButton}
            testID="toggle-screen-button"
          />
          <Button
            title="Set Text"
            onPress={() => setIsModalOpen(true)}
            style={styles.rowButton}
            testID="set-enriched-text-button"
          />
        </View>
        <View style={styles.buttonRow}>
          <Button
            title="Set Example"
            onPress={() => {
              applyHtml(STRESS_TEST_HTML, 'full-stress');
            }}
            style={styles.rowButton}
            testID="set-enriched-text-example-button"
          />
        </View>
        <View style={styles.sectionContainer}>
          <Text style={styles.sectionTitle} testID="viewer-example-current">
            example:{' '}
            {TEXT_VIEWER_HTML_EXAMPLES.find(
              (example) => example.key === activeExampleKey
            )?.title ?? 'custom'}
          </Text>
          <View style={styles.exampleGrid}>
            {TEXT_VIEWER_HTML_EXAMPLES.map((example) => (
              <Button
                key={example.key}
                title={example.title}
                onPress={() => setExample(example)}
                style={styles.exampleButton}
                testID={`text-viewer-example-${example.key}-button`}
              />
            ))}
          </View>
        </View>
        <View style={styles.sectionContainer}>
          <Text style={styles.sectionTitle} testID="ellipsize-current-mode">
            ellipsizeMode: {ellipsizeMode}
          </Text>
          <View style={styles.buttonRow}>
            <Button
              title="Head"
              onPress={() => setEllipsizeMode('head')}
              style={styles.rowButton}
              testID="ellipsize-head-button"
            />
            <Button
              title="Middle"
              onPress={() => setEllipsizeMode('middle')}
              style={styles.rowButton}
              testID="ellipsize-middle-button"
            />
            <Button
              title="Tail"
              onPress={() => setEllipsizeMode('tail')}
              style={styles.rowButton}
              testID="ellipsize-tail-button"
            />
            <Button
              title="Clip"
              onPress={() => setEllipsizeMode('clip')}
              style={styles.rowButton}
              testID="ellipsize-clip-button"
            />
          </View>
        </View>
        <View style={styles.sectionContainer}>
          <Text style={styles.sectionTitle} testID="number-of-lines-current">
            numberOfLines: {numberOfLines === 0 ? 'unset' : numberOfLines}
          </Text>
          <View style={styles.buttonRow}>
            <Button
              title="All"
              onPress={() => setNumberOfLines(0)}
              style={styles.rowButton}
              testID="number-of-lines-all-button"
            />
            <Button
              title="1"
              onPress={() => setNumberOfLines(1)}
              style={styles.rowButton}
              testID="number-of-lines-1-button"
            />
            <Button
              title="2"
              onPress={() => setNumberOfLines(2)}
              style={styles.rowButton}
              testID="number-of-lines-2-button"
            />
          </View>
        </View>
        {html !== null && (
          <View style={styles.rendererContainer} testID="enriched-text">
            <EnrichedText
              key={rendererRevision}
              style={styles.text}
              htmlStyle={enrichedTextHtmlStyle}
              numberOfLines={numberOfLines}
              ellipsizeMode={ellipsizeMode}
              onLinkPress={handleLinkPress}
              onMentionPress={handleMentionPress}
              useHtmlNormalizer
            >
              {html}
            </EnrichedText>
          </View>
        )}
      </ScrollView>
      <ValueModal
        avoidKeyboard
        isOpen={isModalOpen}
        onSubmit={handleSubmit}
        onClose={() => setIsModalOpen(false)}
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
    paddingTop: 50,
    alignItems: 'center',
  },
  buttonRow: {
    flexDirection: 'row',
    width: '100%',
    gap: 8,
  },
  sectionContainer: {
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: 'gray',
    borderRadius: 8,
    padding: 16,
    marginTop: 8,
  },
  sectionTitle: {
    alignSelf: 'flex-start',
    fontSize: 20,
    fontWeight: '600',
    color: 'black',
  },
  exampleGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
    marginTop: 8,
  },
  exampleButton: {
    flexBasis: '48%',
    flexGrow: 1,
    marginTop: 0,
    minHeight: 56,
  },
  rowButton: {
    flex: 1,
  },
  rendererContainer: {
    width: '100%',
    padding: 16,
    borderWidth: StyleSheet.hairlineWidth,
    marginVertical: 16,
    borderRadius: 8,
  },
  text: {
    fontSize: 18,
    color: 'black',
    fontFamily: 'Nunito-Regular',
  },
});
