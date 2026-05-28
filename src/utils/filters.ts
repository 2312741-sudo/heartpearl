// ─────────────────────────────────────────────
//  Beauty Filters (Skia Matrices)
// ─────────────────────────────────────────────

export type FilterType = 'normal' | 'soft-glow' | 'pearl-skin' | 'rosy-blush';

export interface FilterConfig {
  id: FilterType;
  name: string;
  colorMatrix: number[];
  blur: number;
  overlay?: {
    color: string;
    blendMode: 'screen' | 'softLight';
    opacity: number;
  };
}

export const BEAUTY_FILTERS: FilterConfig[] = [
  {
    id: 'normal',
    name: 'Normal',
    colorMatrix: [
      1, 0, 0, 0, 0,
      0, 1, 0, 0, 0,
      0, 0, 1, 0, 0,
      0, 0, 0, 1, 0,
    ],
    blur: 0,
  },
  {
    id: 'soft-glow',
    name: 'Soft Glow',
    colorMatrix: [
      1.05, 0.02, 0.02, 0, 0.06,
      0,    1.00, 0,    0, 0.04,
      0,    0,    0.92, 0, 0.04,
      0,    0,    0,    1, 0
    ],
    blur: 1.2,
    overlay: {
      color: '#FFB0C8', // Tương đương rgba(255, 176, 200, 0.10) ở cường độ nhỏ
      blendMode: 'screen',
      opacity: 0.10,
    }
  },
  {
    id: 'pearl-skin',
    name: 'Pearl Skin',
    colorMatrix: [
      1.05, 0,    0.04, 0, 0.08,
      0,    1.00, 0.02, 0, 0.06,
      0.02, 0.02, 1.05, 0, 0.05,
      0,    0,    0,    1, 0
    ],
    blur: 1.8,
    overlay: {
      color: '#E8D8FF',
      blendMode: 'softLight',
      opacity: 0.12,
    }
  },
  {
    id: 'rosy-blush',
    name: 'Rosy Blush',
    colorMatrix: [
      1.10, 0.02, 0,    0, 0.05,
      0.02, 0.98, 0.02, 0, 0.02,
      0,    0,    0.90, 0, 0.02,
      0,    0,    0,    1, 0
    ],
    blur: 1.0,
    overlay: {
      color: '#FF80A0',
      blendMode: 'screen',
      opacity: 0.12,
    }
  }
];
