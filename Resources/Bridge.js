// music.youtube.com sayfasına enjekte edilir. Çalan şarkının bilgisini
// uygulamaya gönderir ve uygulamadan gelen komutları (oynat, sonraki...) uygular.
(() => {
  if (window.__ytmState) return;

  const $ = (sel, root = document) => root.querySelector(sel);
  const text = (el) => ((el && el.textContent) || '').trim();
  const video = () => $('video');
  const bar = () => $('ytmusic-player-bar');

  // Küçük kapak görselinin büyük sürümünü iste.
  const bigArtwork = (url) => {
    if (!url) return '';
    return url
      .replace(/=w\d+-h\d+/, '=w544-h544')
      .replace(/\/(default|mqdefault|hqdefault|sddefault)\.jpg/, '/hqdefault.jpg');
  };

  window.__ytmState = () => {
    const v = video();
    const b = bar();
    const md = navigator.mediaSession && navigator.mediaSession.metadata;

    const title = (md && md.title) || text(b && $('.title', b));
    const artist = (md && md.artist) || text(b && $('.byline', b)).split('•')[0].trim();
    const album = (md && md.album) || '';

    let art = '';
    if (md && md.artwork && md.artwork.length) art = md.artwork[md.artwork.length - 1].src;
    if (!art) {
      const img = b && $('img.image', b);
      art = img ? img.src : '';
    }

    const hasMedia = !!(v && (v.currentSrc || v.src));
    return {
      title: hasMedia ? title : '',
      artist: hasMedia ? artist : '',
      album: hasMedia ? album : '',
      artwork: hasMedia ? bigArtwork(art) : '',
      playing: !!(v && !v.paused && !v.ended),
      position: v && isFinite(v.currentTime) ? v.currentTime : 0,
      duration: v && isFinite(v.duration) ? v.duration : 0,
    };
  };

  const click = (sel) => {
    const el = $(sel);
    if (!el) return false;
    el.click();
    return true;
  };

  // YouTube'un kendi oynatıcı API'si; yoksa butonlara/video öğesine düş.
  const api = () => {
    const p = $('#movie_player');
    return p && typeof p.playVideo === 'function' ? p : null;
  };
  const play = () => {
    const p = api();
    if (p) p.playVideo();
    else if (!click('ytmusic-player-bar #play-pause-button') && video()) video().play();
  };
  const pause = () => {
    const p = api();
    if (p) p.pauseVideo();
    else if (!click('ytmusic-player-bar #play-pause-button') && video()) video().pause();
  };

  window.__ytmCmd = (cmd, arg) => {
    const v = video();
    switch (cmd) {
      case 'toggle':
        v && !v.paused ? pause() : play();
        break;
      case 'play':
        play();
        break;
      case 'pause':
        pause();
        break;
      case 'next':
        click('ytmusic-player-bar .next-button');
        break;
      case 'previous':
        click('ytmusic-player-bar .previous-button');
        break;
      case 'seek':
        if (!isFinite(arg)) break;
        if (api()) api().seekTo(arg, true);
        else if (v) v.currentTime = arg;
        break;
    }
  };

  // Medya olayları kabarcıklanmaz; capture aşamasında yakalıyoruz.
  const push = () => {
    try {
      window.webkit.messageHandlers.ytm.postMessage(JSON.stringify(window.__ytmState()));
    } catch (e) {}
  };
  ['play', 'pause', 'ended', 'seeked', 'loadedmetadata', 'durationchange', 'emptied'].forEach((ev) =>
    document.addEventListener(ev, push, true)
  );
})();
