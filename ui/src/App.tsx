/* LXR-CAMP — the owner's page at the fire | © 2026 iBoss21 / LXRCore
   open { payload: { id, fuel, fuelMax, daysLeft, fuelItem, guests[], maxGuests, pieces[], kinds[] } } · close
   callbacks: manage { what: 'fuel'|'place'|'take'|'invite'|'uninvite'|'strike', arg } · close */
import { useEffect, useMemo, useState } from 'react';
import { onMessage, applyChrome, makeT, post, pad, type Msg } from './nui';

type Kind = { id: string; item: string; label: string; storage: boolean; rest: boolean; light: boolean };
type Piece = { id: number; kind: string; label: string };
type Guest = { citizenid: string; name: string };
type Camp = { id: number; fuel: number; fuelMax: number; daysLeft: number; fuelItem: string; guests: Guest[]; maxGuests: number; pieces: Piece[]; kinds: Kind[] };

const ICON: Record<string, string> = {
  tent: 'M2 20 L12 4 L22 20 Z M12 4 L12 20',
  bedroll: 'M3 14 h18 v6 H3 Z M3 14 a4 4 0 0 1 4 -4 h10 a4 4 0 0 1 4 4',
  lockbox: 'M3 9 h18 v11 H3 Z M3 9 l2 -4 h14 l2 4 M10 14 h4',
  lantern: 'M9 3 h6 M8 6 h8 l-1 12 H9 Z M12 18 v3 M10 21 h4',
  fire: 'M12 3 c1 4 5 5 5 10 a5 5 0 0 1 -10 0 c0 -3 2 -4 2 -6 c1 1 2 2 3 1 z',
};
const Glyph = ({ d }: { d: string }) => <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinejoin="round" strokeLinecap="round"><path d={d} /></svg>;

export function App() {
  const [C, setC] = useState<Camp | null>(null);
  const [L, setL] = useState<Record<string, string>>({});
  const [busy, setBusy] = useState(false);
  const [confirm, setConfirm] = useState(false);
  const [logs, setLogs] = useState(1);
  const t = makeT(L);

  useEffect(() => onMessage((m: Msg) => {
    applyChrome(m);
    if (m.locale) setL(m.locale);
    if (m.action === 'open') { setC(m.payload); setConfirm(false); setLogs(1); }
    if (m.action === 'close') setC(null);
  }), []);
  useEffect(() => { const k = (e: KeyboardEvent) => { if (e.key === 'Escape') { if (confirm) setConfirm(false); else if (C) post('close'); } }; document.addEventListener('keydown', k); return () => document.removeEventListener('keydown', k); }, [C, confirm]);

  const manage = async (what: string, arg?: any) => {
    if (busy) return false; setBusy(true);
    const r = await post<{ ok: boolean; data?: Camp }>('manage', { what, arg });
    setBusy(false);
    if (r.ok && r.data) setC(r.data);
    return r.ok;
  };

  const placed = useMemo(() => new Set((C?.pieces || []).map((p) => p.kind)), [C]);
  if (!C) return null;
  const room = C.fuelMax - C.fuel;
  const low = C.daysLeft <= 2;

  return (
    <div id="app">
      <section className="cp lxr-hit">
        <header className="cp-top">
          <img className="cp-logo" src="img/lxrcore-logo.png" alt="" />
          <div className="cp-head">
            <span className="lxr-mono lxr-t-ash">{t('ui.kicker')} · {pad(C.id)}</span>
            <h1 className="lxr-cut cp-title">{t('ui.title')}</h1>
          </div>
          <span className="lxr-grow" />
          <span className="cp-hint lxr-mono lxr-t-smoke"><span className="lxr-key">Esc</span> {t('ui.hint_close')}</span>
        </header>

        {/* ── the fire and its woodpile ── */}
        <div className={'cp-fire' + (low ? ' is-low' : '')}>
          <span className="cp-fire__glyph"><Glyph d={ICON.fire} /></span>
          <div className="cp-fire__body">
            <div className="cp-fire__row"><span className="lxr-cut cp-fire__name">{t('ui.fire')}</span><span className="lxr-grow" /><span className="lxr-mono cp-fire__days">{t('ui.days', { n: C.daysLeft })}</span></div>
            <div className="cp-wood" title={C.fuel + ' / ' + C.fuelMax}>
              {Array.from({ length: C.fuelMax }, (_, i) => <span key={i} className={'cp-wood__log' + (i < C.fuel ? ' is-lit' : '')} />)}
            </div>
            <div className="cp-fire__row lxr-mono lxr-t-smoke"><span>{C.fuelItem}</span><span className="lxr-grow" /><span className="lxr-num">{C.fuel}</span><span>/ {C.fuelMax}</span></div>
          </div>
        </div>
        <div className="cp-add">
          <span className="lxr-mono lxr-t-smoke">{t('ui.from_satchel')}</span>
          <span className="lxr-grow" />
          <div className="cp-stepper">
            <button className="lxr-btn lxr-btn-ghost lxr-btn-sm" disabled={logs <= 1} onClick={() => setLogs((n) => Math.max(1, n - 1))}>−</button>
            <span className="lxr-num cp-stepper__n">{logs}</span>
            <button className="lxr-btn lxr-btn-ghost lxr-btn-sm" disabled={logs >= room} onClick={() => setLogs((n) => Math.min(room, n + 1))}>+</button>
          </div>
          <button className="lxr-btn lxr-btn-sm" disabled={busy || room <= 0} onClick={() => manage('fuel', logs)}>{logs > 1 ? t('ui.add_wood_n', { n: logs }) : t('ui.add_wood')}</button>
        </div>

        {/* ── pieces: what stands, what could ── */}
        <div className="cp-sec"><span className="lxr-mono">{t('ui.pieces')}</span><span className="lxr-grow" /><span className="lxr-mono lxr-t-smoke">{pad(C.pieces.length)} / {pad(C.kinds.length)}</span></div>
        <ul className="cp-list">
          {C.kinds.map((k, i) => {
            const piece = C.pieces.find((p) => p.kind === k.id);
            const tags = [k.storage && t('ui.storage'), k.rest && t('ui.rest_piece'), k.light && t('ui.light')].filter(Boolean).join(' · ');
            return (
              <li key={k.id} className={'cp-item' + (piece ? ' is-up' : '')}>
                <span className="lxr-row-index">{pad(i + 1)}</span>
                <span className="cp-item__glyph"><Glyph d={ICON[k.id] || ICON.lockbox} /></span>
                <div className="cp-item__body"><span className="cp-item__name">{k.label}</span><span className="lxr-mono cp-item__tags">{tags || '—'}</span></div>
                <span className="lxr-grow" />
                {piece
                  ? <button className="lxr-btn lxr-btn-ghost lxr-btn-sm" disabled={busy} onClick={() => manage('take', piece.id)}>{t('ui.take')}</button>
                  : <button className="lxr-btn lxr-btn-sm" disabled={busy || placed.has(k.id)} onClick={() => manage('place', k.id)}>{t('ui.place')}</button>}
              </li>
            );
          })}
        </ul>

        {/* ── guests ── */}
        <div className="cp-sec"><span className="lxr-mono">{t('ui.guests')}</span><span className="lxr-grow" /><span className="lxr-mono lxr-t-smoke">{pad(C.guests.length)} / {pad(C.maxGuests)}</span></div>
        <ul className="cp-list">
          {C.guests.map((g, i) => (
            <li key={g.citizenid} className="cp-item is-up">
              <span className="lxr-row-index">{pad(i + 1)}</span>
              <div className="cp-item__body"><span className="cp-item__name">{g.name}</span><span className="lxr-mono cp-item__tags">{g.citizenid}</span></div>
              <span className="lxr-grow" />
              <button className="lxr-btn lxr-btn-ghost lxr-btn-sm" disabled={busy} onClick={() => manage('uninvite', g.citizenid)}>{t('ui.uninvite')}</button>
            </li>
          ))}
          {C.guests.length < C.maxGuests && (
            <li className="cp-item cp-item--add"><button className="lxr-btn lxr-btn-ghost lxr-btn-sm" disabled={busy} onClick={() => manage('invite')}>+ {t('ui.invite')}</button></li>
          )}
        </ul>

        <footer className="cp-foot">
          {!confirm && <button className="lxr-btn lxr-btn-ghost lxr-btn-sm cp-strike" disabled={busy} onClick={() => setConfirm(true)}>{t('ui.strike')}</button>}
          {confirm && (
            <div className="cp-confirm">
              <span className="lxr-t-ash">{t('ui.strike_confirm')}</span>
              <div className="cp-confirm__row">
                <button className="lxr-btn lxr-btn-sm cp-strike" disabled={busy} onClick={() => manage('strike')}>{t('ui.strike')}</button>
                <button className="lxr-btn lxr-btn-ghost lxr-btn-sm" onClick={() => setConfirm(false)}>{t('ui.hint_close')}</button>
              </div>
            </div>
          )}
        </footer>
      </section>
    </div>
  );
}
