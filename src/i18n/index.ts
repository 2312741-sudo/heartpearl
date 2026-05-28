import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import { en } from './en';
import { vi } from './vi';

i18n
  .use(initReactI18next)
  .init({
    resources: {
      en,
      vi
    },
    lng: 'vi', // Default language
    fallbackLng: 'en',
    interpolation: {
      escapeValue: false // React already does escaping
    },
    compatibilityJSON: 'v3' as any,
  });

export default i18n;
