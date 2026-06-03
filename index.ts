import { registerRootComponent } from 'expo';
import App from './App';

try {
  const { registerWidgetTaskHandler } = require('react-native-android-widget');
  const { widgetTaskHandler } = require('./src/widgets/androidWidget');
  registerWidgetTaskHandler(widgetTaskHandler);
} catch (e) {
  console.warn('Failed to register Android widget task handler (likely in Expo Go)', e);
}

// registerRootComponent calls AppRegistry.registerComponent('main', () => App);
// It also ensures that whether you load the app in Expo Go or in a native build,
// the environment is set up appropriately
registerRootComponent(App);
