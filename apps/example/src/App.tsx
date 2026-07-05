import { useState } from 'react';
import { SafeAreaView, StyleSheet } from 'react-native';
import { DevScreen } from './screens/DevScreen';
import { TestScreen } from './screens/TestScreen';
import { EnrichedTextScreen } from './screens/EnrichedTextScreen';

type Screen = 'dev' | 'test' | 'enrichedText';

export default function App() {
  const [screen, setScreen] = useState<Screen>('dev');

  if (screen === 'test') {
    return (
      <SafeAreaView style={styles.container}>
        <TestScreen
          onSwitch={() => setScreen('dev')}
          onSwitchEnrichedText={() => setScreen('enrichedText')}
        />
      </SafeAreaView>
    );
  }

  if (screen === 'enrichedText') {
    return (
      <SafeAreaView style={styles.container}>
        <EnrichedTextScreen onSwitch={() => setScreen('test')} />
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.container}>
      <DevScreen onSwitch={() => setScreen('test')} />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: 'white',
  },
});
