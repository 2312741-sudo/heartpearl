export type FilterType = 'normal' | 'warm' | 'cool' | 'vintage' | 'bw' | 'cyberpunk';

export interface FilterConfig {
  id: FilterType;
  name: string;
  overlayColor: string;
  opacity: number;
}

export const CAMERA_FILTERS: FilterConfig[] = [
  {
    id: 'normal',
    name: 'Normal',
    overlayColor: 'transparent',
    opacity: 0,
  },
  {
    id: 'warm',
    name: 'Ấm áp',
    overlayColor: '#ff9900',
    opacity: 0.15,
  },
  {
    id: 'cool',
    name: 'Lạnh',
    overlayColor: '#0066ff',
    opacity: 0.15,
  },
  {
    id: 'vintage',
    name: 'Cổ điển',
    overlayColor: '#ffb366',
    opacity: 0.2,
  },
  {
    id: 'bw',
    name: 'Trắng đen',
    overlayColor: '#000000', // Không thể tạo B&W thật với overlay, giả màu tối một chút
    opacity: 0.4,
  },
  {
    id: 'cyberpunk',
    name: 'Neon',
    overlayColor: '#ff00ff',
    opacity: 0.2,
  },
];
