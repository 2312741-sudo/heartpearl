import React from 'react';
import { FlexWidget, ImageWidget, TextWidget } from 'react-native-android-widget';

export function TamChauWidget({ imageUrl }: { imageUrl?: string }) {
  return (
    <FlexWidget
      style={{
        height: 'match_parent',
        width: 'match_parent',
        backgroundColor: '#0A0A0F',
        borderRadius: 16,
        alignItems: 'center',
        justifyContent: 'center',
      }}
      clickAction="openApp"
    >
      {imageUrl ? (
        <ImageWidget
          image={imageUrl as any}
          imageWidth={300}
          imageHeight={300}
          style={{
            width: 'match_parent',
            height: 'match_parent',
            borderRadius: 16,
          }}
        />
      ) : (
        <FlexWidget
          style={{
            alignItems: 'center',
            justifyContent: 'center',
            width: 'match_parent',
            height: 'match_parent',
          }}
        >
          <TextWidget
            text="HeartPearl"
            style={{
              fontSize: 18,
              fontWeight: 'bold',
              color: '#FFFFFF',
            }}
          />
          <TextWidget
            text="Chưa có ảnh mới"
            style={{
              fontSize: 12,
              color: '#8E8E93',
              marginTop: 4,
            }}
          />
        </FlexWidget>
      )}
    </FlexWidget>
  );
}

export async function widgetTaskHandler(props: any) {
  const { widgetAction, renderWidget } = props;

  if (widgetAction === 'WIDGET_ADDED' || widgetAction === 'WIDGET_UPDATE') {
    try {
      const AsyncStorage = require('@react-native-async-storage/async-storage').default;
      const latestPhotoUrl = (await AsyncStorage.getItem('latestPhotoUrl')) || '';
      renderWidget(<TamChauWidget imageUrl={latestPhotoUrl} />);
    } catch (error) {
      console.warn('[WidgetTaskHandler] Failed to render widget:', error);
      renderWidget(<TamChauWidget />);
    }
  }
}
