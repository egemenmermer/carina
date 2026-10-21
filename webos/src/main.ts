// Carina for webOS — entry point.
import './styles.css';
import { initApp, pop, push, top } from './app';
import { initLanguage } from './i18n';
import { applyScale } from './platform';
import { PlaylistsScreen } from './screens/playlists';
import { PlayerScreen } from './screens/player';
import { AddPlaylistScreen } from './screens/add-playlist';
import { store } from './store';

function start(): void {
  applyScale();
  window.addEventListener('resize', applyScale);
  initLanguage();
  const root = document.getElementById('app') as HTMLElement;
  initApp(root);
  push(new PlaylistsScreen());
  if (!store.playlists().length) push(new AddPlaylistScreen());
  // webOS keeps suspended apps in memory: leave the player (and free the
  // decoder) when the app goes to the background.
  document.addEventListener('webkitvisibilitychange', onVisibility);
  document.addEventListener('visibilitychange', onVisibility);
}

function onVisibility(): void {
  const hidden = document.hidden || (document as unknown as { webkitHidden?: boolean }).webkitHidden;
  if (hidden && top() instanceof PlayerScreen) pop();
}

if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start);
else start();
