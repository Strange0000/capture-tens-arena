import { Router } from "express";

export const playtestRouter = Router();

playtestRouter.get("/", (_req, res) => {
  res.type("html").send(`<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Capture Tens Arena Playtest</title>
  <style>
    * { box-sizing: border-box; }
    body {
      margin: 0;
      min-height: 100vh;
      font-family: Inter, system-ui, Segoe UI, sans-serif;
      color: #f7fbff;
      background: radial-gradient(circle at 50% 35%, #18584c 0, #101826 42%, #070b13 100%);
    }
    header { display: flex; justify-content: space-between; align-items: center; padding: 18px; }
    h1 { font-size: 24px; margin: 0; letter-spacing: 0; }
    button {
      border: 0;
      border-radius: 8px;
      padding: 12px 14px;
      font-weight: 900;
      background: #48e5c2;
      color: #061016;
      cursor: pointer;
    }
    .wrap { padding: 0 16px 18px; display: grid; gap: 14px; }
    .table {
      min-height: 390px;
      border: 1px solid rgba(255,255,255,.16);
      border-radius: 16px;
      position: relative;
      overflow: hidden;
      background: radial-gradient(circle, #187360 0, #0b2a31 58%, #071018 100%);
    }
    .seat {
      position: absolute;
      padding: 8px 10px;
      border-radius: 8px;
      background: rgba(16,24,38,.84);
      border: 1px solid rgba(255,255,255,.18);
      font-size: 13px;
      font-weight: 800;
    }
    .active { background: #48e5c2; color: #061016; }
    .s0 { bottom: 14px; left: 50%; transform: translateX(-50%); }
    .s1 { right: 14px; top: 50%; transform: translateY(-50%); }
    .s2 { top: 14px; left: 50%; transform: translateX(-50%); }
    .s3 { left: 14px; top: 50%; transform: translateY(-50%); }
    .center {
      position: absolute;
      inset: 42%;
      display: grid;
      place-items: center;
      text-align: center;
      font-weight: 900;
      color: #ffc857;
    }
    .panel {
      border-radius: 8px;
      padding: 12px;
      background: rgba(16,24,38,.9);
      border: 1px solid rgba(255,255,255,.12);
    }
    .hand { display: flex; gap: 8px; overflow-x: auto; padding: 8px 0; }
    .card {
      flex: 0 0 64px;
      height: 92px;
      border-radius: 8px;
      background: #fff;
      color: #101010;
      border: 2px solid #fff;
      display: flex;
      flex-direction: column;
      justify-content: space-between;
      padding: 8px;
      font-weight: 950;
      cursor: pointer;
    }
    .red { color: #b91c1c; }
    .power { border-color: #ffc857; box-shadow: 0 0 18px rgba(255,200,87,.65); }
    .suits { display: grid; grid-template-columns: repeat(4, 1fr); gap: 8px; }
    .log { font-size: 12px; opacity: .82; min-height: 18px; }
    .card.small { flex: 0 0 44px; height: 64px; font-size: 11px; padding: 5px; }
    .ten { border-color: #48e5c2; box-shadow: 0 0 10px rgba(72,229,194,.5); }
    .trick-card { position: absolute; display: flex; align-items: center; justify-content: center; animation: popIn .32s cubic-bezier(.34,1.56,.64,1); }
    .tc0 { bottom: 42px; left: 50%; transform: translateX(-50%); }
    .tc1 { right: 42px; top: 50%; transform: translateY(-50%); }
    .tc2 { top: 42px; left: 50%; transform: translateX(-50%); }
    .tc3 { left: 42px; top: 50%; transform: translateY(-50%); }
    .caps { display: flex; justify-content: space-between; font-size: 12px; font-weight: 700; padding: 6px 12px; background: rgba(16,24,38,.85); border-radius: 8px; border: 1px solid rgba(255,255,255,.1); }
    .caps span { color: #ffc857; }

    /* Card animations */
    .card { transition: transform .15s ease, box-shadow .15s ease; }
    .card:hover { transform: translateY(-6px); box-shadow: 0 8px 24px rgba(0,0,0,.5); }
    .card:active { transform: translateY(-2px) scale(.97); }
    .hand .card { animation: dealIn .35s ease-out both; }

    /* Seat badge pulse for active player */
    .seat { transition: background .2s ease, color .2s ease; }
    .active { animation: pulse 1.8s ease-in-out infinite; }

    /* Trick completion flash */
    .trick-won { animation: trickFlash .6s ease; }

    /* Winner banner */
    .win-banner { animation: bannerIn .5s cubic-bezier(.34,1.56,.64,1); }

    @keyframes dealIn {
      from { opacity: 0; transform: translateY(20px) scale(.85); }
      to { opacity: 1; transform: translateY(0) scale(1); }
    }
    @keyframes popIn {
      from { opacity: 0; transform: scale(.5); }
      to { opacity: 1; transform: scale(1); }
    }
    @keyframes pulse {
      0%, 100% { box-shadow: 0 0 0 0 rgba(72,229,194,.4); }
      50% { box-shadow: 0 0 0 8px rgba(72,229,194,0); }
    }
    @keyframes trickFlash {
      0% { opacity: 1; }
      50% { opacity: .3; }
      100% { opacity: 1; }
    }
    @keyframes bannerIn {
      from { opacity: 0; transform: scale(.7); }
      to { opacity: 1; transform: scale(1); }
    }
  </style>
</head>
<body>
  <header>
    <h1>Capture Tens Arena</h1>
    <button id="start">Hard Bot Match</button>
  </header>
  <main class="wrap">
    <section class="table" id="table"><div class="center">Start a match</div></section>
    <section class="panel" id="power" hidden>
      <strong>Choose Power Suit</strong>
      <div class="suits">
        <button data-suit="hearts">Hearts</button>
        <button data-suit="diamonds">Diamonds</button>
        <button data-suit="clubs">Clubs</button>
        <button data-suit="spades">Spades</button>
      </div>
    </section>
    <section class="caps"><span id="caps-a">A: 0 tens</span><span id="caps-b">B: 0 tens</span></section>
    <section class="panel">
      <strong>Your Hand</strong>
      <div class="hand" id="hand"></div>
      <div class="log" id="log">Connecting...</div>
    </section>
  </main>
  <script src="/socket.io/socket.io.js"></script>
  <script>
    let socket;
    let match;
    let lastRenderedTrickIndex = -1;
    let isShowingOldTrick = false;
    let trickTimeout = null;
    const log = (text) => document.getElementById('log').textContent = text;
    const SYMBOLS = { hearts: '♥', diamonds: '♦', clubs: '♣', spades: '♠' };
    const symbol = (suit) => SYMBOLS[suit] || '?';
    const red = (suit) => suit === 'hearts' || suit === 'diamonds';

    // Seat → CSS position class
    const SEAT_POS = { 0: 's0', 1: 's1', 2: 's2', 3: 's3' };

    async function boot() {
      const response = await fetch('/auth/guest', { method: 'POST' });
      const session = await response.json();
      socket = io({ auth: { token: session.token } });
      socket.on('connect', () => log('Connected as ' + session.user.username));
      socket.on('match:created', () => log('Match created — waiting for state…'));
      socket.on('match:state', (state) => { match = state; render(); });
      socket.on('error', (err) => log('Error: ' + (err.message || err)));
    }

    function makeCard(card, small) {
      const div = document.createElement('div');
      div.className = 'card' + (small ? ' small' : '') +
        (red(card.suit) ? ' red' : '') +
        (match.powerSuit === card.suit ? ' power' : '') +
        (card.rank === '10' ? ' ten' : '');
      div.innerHTML = '<span>' + card.rank + '</span><span style="font-size:' + (small ? 18 : 28) + 'px;text-align:center">' + symbol(card.suit) + '</span><span></span>';
      return div;
    }

    function render() {
      const table = document.getElementById('table');
      table.innerHTML = '';

      // Player seat badges
      for (const player of match.players) {
        const div = document.createElement('div');
        div.className = 'seat ' + SEAT_POS[player.seat] + (player.seat === match.currentTurnSeat ? ' active' : '');
        div.textContent = player.username + ' ' + player.cardCount;
        table.appendChild(div);
      }

      let trickToRender = match.currentTrick;
      
      if (match.currentTrick && match.currentTrick.plays.length === 0 && match.completedTricks && match.completedTricks.length > 0) {
        const lastTrick = match.completedTricks[match.completedTricks.length - 1];
        if (lastRenderedTrickIndex !== lastTrick.index) {
          trickToRender = lastTrick;
          isShowingOldTrick = true;
          if (trickTimeout) clearTimeout(trickTimeout);
          trickTimeout = setTimeout(() => {
            lastRenderedTrickIndex = lastTrick.index;
            isShowingOldTrick = false;
            render();
          }, 1800);
        }
      } else {
        isShowingOldTrick = false;
        if (trickTimeout) clearTimeout(trickTimeout);
      }

      // Trick cards in cross layout
      if (trickToRender && (match.phase === 'playing' || isShowingOldTrick)) {
        for (const play of trickToRender.plays) {
          const wrap = document.createElement('div');
          wrap.className = 'trick-card tc' + play.seat;
          if (isShowingOldTrick && play.seat === trickToRender.winnerSeat) wrap.className += ' trick-won';
          wrap.appendChild(makeCard(play.card, true));
          table.appendChild(wrap);
        }
      }

      // Centre label
      const center = document.createElement('div');
      center.className = 'center';
      if (match.winnerTeam) {
        center.className += ' win-banner';
        center.textContent = '🏆 Team ' + match.winnerTeam + ' wins!';
      } else if (match.powerSuit) {
        center.textContent = symbol(match.powerSuit) + ' ' + match.powerSuit.toUpperCase();
      } else {
        center.textContent = 'Choose power suit';
      }
      table.appendChild(center);

      // Captures bar
      const caps = match.captures;
      const formatTens = (tensArray) => tensArray ? tensArray.map(c => symbol(c.suit)).join(' ') : '';
      document.getElementById('caps-a').textContent =
        'A: ' + caps.A.tens + ' tens [' + formatTens(caps.A.tenCards) + '] · ' + caps.A.cards + ' cards';
      document.getElementById('caps-b').textContent =
        'B: ' + caps.B.tens + ' tens [' + formatTens(caps.B.tenCards) + '] · ' + caps.B.cards + ' cards';

      document.getElementById('power').hidden = match.phase !== 'power-select';
      const hand = document.getElementById('hand');
      hand.innerHTML = '';
      match.hand.forEach(function(card, i) {
        const div = makeCard(card, false);
        div.style.cursor = 'pointer';
        div.style.animationDelay = (i * 0.05) + 's';
        div.onclick = function() { socket.emit('card:play', { matchId: match.id, cardId: card.id }); };
        hand.appendChild(div);
      });
      log('Phase: ' + match.phase + '  ·  Turn seat: ' + match.currentTurnSeat +
        '  ·  Trick ' + (match.completedTricks?.length ?? 0) + '/13');
    }

    document.getElementById('start').onclick = () => socket.emit('bot:offline', { difficulty: 'hard' });
    document.querySelectorAll('[data-suit]').forEach((button) => {
      button.onclick = () => socket.emit('power:select', { matchId: match.id, suit: button.dataset.suit });
    });
    boot().catch((error) => log(error.message));
  </script>
</body>
</html>`);
});
