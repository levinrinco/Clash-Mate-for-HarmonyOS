import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';

export interface ThemePalette {
  id: string;
  background: string;
  surface: string;
  textPrimary: string;
  textSecondary: string;
  accent: string;
  accentText: string;
  stopped: string;
  chip: string;
  shadow: string;
}

export interface WidgetPalette {
  id: string;
  background: string;
  surface: string;
  text: string;
  secondary: string;
  accent: string;
  accentText: string;
  muted: string;
}

interface ThemeSet {
  id: string;
  light: ThemePalette;
  dark: ThemePalette;
}

const SETS: ThemeSet[] = [
  {
    id: 'mist',
    light: {
      id: 'mist', background: '#F2F5F6', surface: '#FCFDFD', textPrimary: '#2E3A40',
      textSecondary: '#6F7E86', accent: '#5C7A8A', accentText: '#FFFFFF',
      stopped: '#9AA7AE', chip: '#E9F0F2', shadow: '#14000000'
    },
    dark: {
      id: 'mist', background: '#12171A', surface: '#1B2226', textPrimary: '#E8EEF1',
      textSecondary: '#9BABB3', accent: '#8FB2C4', accentText: '#0C161B',
      stopped: '#5F6C72', chip: '#252E33', shadow: '#40000000'
    }
  },
  {
    id: 'sage',
    light: {
      id: 'sage', background: '#F3F5F0', surface: '#FBFCF8', textPrimary: '#31382C',
      textSecondary: '#75806C', accent: '#77896D', accentText: '#FFFFFF',
      stopped: '#A1AB95', chip: '#EAF0E4', shadow: '#14000000'
    },
    dark: {
      id: 'sage', background: '#141812', surface: '#1D241A', textPrimary: '#EEF2E8',
      textSecondary: '#A8B39D', accent: '#A6BA97', accentText: '#10150B',
      stopped: '#667059', chip: '#2A3224', shadow: '#40000000'
    }
  },
  {
    id: 'rose',
    light: {
      id: 'rose', background: '#F8F3F4', surface: '#FEFBFC', textPrimary: '#3A3033',
      textSecondary: '#8B757B', accent: '#A97E89', accentText: '#FFFFFF',
      stopped: '#B8A3A8', chip: '#F3E9EC', shadow: '#14000000'
    },
    dark: {
      id: 'rose', background: '#191315', surface: '#241B1E', textPrimary: '#F5E9EC',
      textSecondary: '#C0A8AE', accent: '#D0A6B1', accentText: '#1B0E12',
      stopped: '#705B60', chip: '#33262A', shadow: '#40000000'
    }
  },
  {
    id: 'sand',
    light: {
      id: 'sand', background: '#F7F2EA', surface: '#FEFBF6', textPrimary: '#3A332A',
      textSecondary: '#857B6C', accent: '#A38A6B', accentText: '#FFFFFF',
      stopped: '#B4A791', chip: '#F0E9DD', shadow: '#14000000'
    },
    dark: {
      id: 'sand', background: '#191510', surface: '#241E17', textPrimary: '#F7EFE4',
      textSecondary: '#C4B29B', accent: '#D3B58E', accentText: '#1B1206',
      stopped: '#736453', chip: '#342B21', shadow: '#40000000'
    }
  },
  {
    id: 'lavender',
    light: {
      id: 'lavender', background: '#F5F2F7', surface: '#FDFBFE', textPrimary: '#342F3A',
      textSecondary: '#7C7189', accent: '#827596', accentText: '#FFFFFF',
      stopped: '#A79CB2', chip: '#EDE7F1', shadow: '#14000000'
    },
    dark: {
      id: 'lavender', background: '#16131A', surface: '#201B26', textPrimary: '#F1ECF7',
      textSecondary: '#B4A6C4', accent: '#BCAAD4', accentText: '#150F1D',
      stopped: '#6A5F78', chip: '#2E2737', shadow: '#40000000'
    }
  },
  {
    id: 'classic',
    light: {
      id: 'classic', background: '#FAFAFA', surface: '#FFFFFF', textPrimary: '#000000',
      textSecondary: '#99000000', accent: '#1E4376', accentText: '#FFFFFF',
      stopped: '#808080', chip: '#F0F1F3', shadow: '#14000000'
    },
    dark: {
      id: 'classic', background: '#121212', surface: '#1C1C1C', textPrimary: '#F5F5F5',
      textSecondary: '#B0B0B0', accent: '#6E9BD6', accentText: '#0A1524',
      stopped: '#5C5C5C', chip: '#262626', shadow: '#40000000'
    }
  }
];

const WIDGETS: WidgetPalette[] = [
  {
    id: 'ocean', background: '#0B1826', surface: '#17334F', text: '#F2F8FF',
    secondary: '#A9C1D9', accent: '#4FA3FF', accentText: '#05121F', muted: '#1C3552'
  },
  {
    id: 'forest', background: '#0B1A14', surface: '#173D2E', text: '#EFFBF5',
    secondary: '#A5C9B9', accent: '#2FD39B', accentText: '#04140D', muted: '#1B3B2E'
  },
  {
    id: 'plum', background: '#171022', surface: '#33204A', text: '#F8F1FF',
    secondary: '#C3AFD9', accent: '#B98CF7', accentText: '#150A24', muted: '#372650'
  },
  {
    id: 'amber', background: '#1D1410', surface: '#3A281C', text: '#FFF6EC',
    secondary: '#D3B79F', accent: '#F2A65A', accentText: '#1C0F05', muted: '#3F2C20'
  },
  {
    id: 'graphite', background: '#0F1113', surface: '#22282D', text: '#F5F7F9',
    secondary: '#AAB5BD', accent: '#48D6C8', accentText: '#04100F', muted: '#2A3136'
  },
  {
    id: 'cloud', background: '#F4F7FA', surface: '#DDE8F1', text: '#1D2A33',
    secondary: '#66757F', accent: '#3D7EA6', accentText: '#FFFFFF', muted: '#D8E3EC'
  },
  {
    id: 'linen', background: '#FAF6EE', surface: '#EFE2CF', text: '#332A20',
    secondary: '#7C6C58', accent: '#B07C4F', accentText: '#FFFFFF', muted: '#EADDC9'
  },
  {
    id: 'mint', background: '#F1F9F5', surface: '#D9EDE3', text: '#1E322A',
    secondary: '#5F786D', accent: '#2E8B6C', accentText: '#FFFFFF', muted: '#D5EAE0'
  },
  {
    id: 'blush', background: '#FBF4F5', surface: '#F0DDE1', text: '#3A2A2E',
    secondary: '#866D73', accent: '#B36B7D', accentText: '#FFFFFF', muted: '#EFDADD'
  }
];

export class Theme {
  static readonly DEFAULT: string = 'mist';

  static get(id: string, dark: boolean): ThemePalette {
    for (const set of SETS) {
      if (set.id === id) {
        return dark ? set.dark : set.light;
      }
    }
    return dark ? SETS[0].dark : SETS[0].light;
  }

  static resolveDark(mode: string, systemDark: boolean): boolean {
    if (mode === 'dark') {
      return true;
    }
    if (mode === 'light') {
      return false;
    }
    return systemDark;
  }

  static async applyBars(context: common.Context, palette: ThemePalette): Promise<void> {
    try {
      const win = await window.getLastWindow(context);
      const dark = Theme.luminance(palette.background) < 0.5;
      await win.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        navigationBarColor: '#00000000',
        statusBarContentColor: dark ? '#FFFFFF' : '#000000',
        navigationBarContentColor: dark ? '#FFFFFF' : '#000000'
      });
    } catch (error) {
      console.error('apply system bar failed');
    }
  }

  private static luminance(color: string): number {
    if (color.length < 7 || color[0] !== '#') {
      return 1;
    }
    const hex = color.substring(1);
    const r = parseInt(hex.substring(0, 2), 16);
    const g = parseInt(hex.substring(2, 4), 16);
    const b = parseInt(hex.substring(4, 6), 16);
    return (r * 299 + g * 587 + b * 114) / 1000;
  }
}

export class WidgetTheme {
  static readonly DEFAULT: string = 'ocean';

  static get(id: string): WidgetPalette {
    for (const palette of WIDGETS) {
      if (palette.id === id) {
        return palette;
      }
    }
    return WIDGETS[0];
  }
}
