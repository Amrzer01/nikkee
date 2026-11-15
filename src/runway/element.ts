import { CatalogVariant } from './catalog';
import {
  findMatchingVariant,
  isOptionValueAvailable,
  stylingBag,
} from './bag';
import {
  BODY_COUNT,
  computeClassicPose,
  computeFootFractionFromAlpha,
  computeFrameHeight,
  computeRingPose,
  computeStageMetrics,
  LOOK_COUNT,
  ringSlotRank,
  RunwayMode,
  shortestLoopDelta,
  stepSpring,
  wrapMod,
} from './math';

interface BodyState {
  el: HTMLElement;
  hit: HTMLButtonElement | null;
  index: number;
  lookIndex: number;
  w: number;
  x: number;
  g: number;
  v: number;
  from: number;
  onTrip: boolean;
  prevGoal: number;
  blurStr: string;
}

const SHEET_TOKENS = [
  '--rw-panel',
  '--rw-text',
  '--rw-muted',
  '--rw-line',
  '--rw-accent',
  '--rw-on-accent',
  '--rw-btn-bg',
  '--rw-btn-fg',
  '--rw-btn-radius',
  '--rw-pill-radius',
  '--rw-bar-r',
  '--rw-thumb-radius',
  '--rw-pt-size',
  '--rw-price',
  '--rw-opt',
  '--rw-ease',
  '--rw-ease-sheet',
  '--rw-ease-spring',
];

export class RunwaySection extends HTMLElement {
  private stage!: HTMLElement;
  private actorsEl!: HTMLElement;
  private heroesEl!: HTMLElement;
  private panelEl!: HTMLElement;
  private liveEl: HTMLElement | null = null;
  private piecesEl: HTMLElement | null = null;
  private autoBtn: HTMLButtonElement | null = null;
  private cursorEl: HTMLElement | null = null;
  private lbEl: HTMLElement | null = null;
  private lbStageEl: HTMLElement | null = null;
  private lbKickerEl: HTMLElement | null = null;
  private lbNameEl: HTMLElement | null = null;

  private bodies: BodyState[] = [];
  private heroes: HTMLElement[] = [];
  private ticks: HTMLButtonElement[] = [];
  private panels: HTMLElement[] = [];
  private footByLook: number[] = Array(LOOK_COUNT).fill(0);

  private index = 0;
  private target = 0;
  private cur = 0;
  private vel = 0;
  private still = false;
  private mode: RunwayMode = 'ring';
  private isMobile = false;
  private W = 0;
  private H = 0;
  private unit = 200;
  private fs = 1.08;
  private latchedVh = 0;
  private lastWinW = 0;

  private reducedMotion = false;
  private enableBlur = true;
  private speedMs = 5000;
  private autoplayEnabled = true;

  private playing = false;
  private engaged = false;
  private panelHover = false;
  private zoomed = false;
  private visible = true;
  private dragging = false;

  private rafId: number | null = null;
  private lastTs = 0;
  private autoTimer: number | null = null;
  private resizeTimer: number | null = null;
  private wheelLockTimer: number | null = null;
  private wheelAcc = 0;
  private wheelLocked = false;
  private suppressClickUntil = 0;

  // Pointer drag state
  private dragPointerId: number | null = null;
  private dragStartX = 0;
  private dragStartY = 0;
  private dragStartTarget = 0;
  private dragSamples: Array<{ x: number; time: number }> = [];
  private dragAbandoned = false;

  // Custom cursor state
  private hasFineCursor = false;
  private cursorX = 0;
  private cursorY = 0;
  private cursorTx = 0;
  private cursorTy = 0;
  private cursorActive = false;
  private cursorRaf: number | null = null;

  // Observers & sheet state
  private revealIo: IntersectionObserver | null = null;
  private visIo: IntersectionObserver | null = null;
  private stageRo: ResizeObserver | null = null;
  private sheetHost: HTMLElement | null = null;
  private activeSheetCard: HTMLElement | null = null;
  private activeSheetPicker: HTMLElement | null = null;
  private activeSheetPlaceholder: Comment | null = null;
  private lbCloseTimer: number | null = null;

  // Bound listeners for cleanup
  private onWinResize = () => {
    if (this.resizeTimer !== null) window.clearTimeout(this.resizeTimer);
    this.resizeTimer = window.setTimeout(() => this.measure(), 120);
  };
  private onDocVisChange = () => {
    if (document.hidden) {
      this.stopLoop();
    } else {
      this.lastTs = 0;
      this.kick();
    }
  };
  private onKeyDown = (ev: KeyboardEvent) => {
    if (ev.key === 'Escape') {
      if (this.activeSheetCard) {
        ev.preventDefault();
        const card = this.activeSheetCard;
        this.closeSheet();
        const addBtn = card.querySelector<HTMLButtonElement>('[data-rw-add]');
        addBtn?.focus({ preventScroll: true });
      } else if (this.zoomed) {
        ev.preventDefault();
        this.closePopup();
      }
      return;
    }

    if (
      (ev.key === 'ArrowRight' || ev.key === 'ArrowLeft') &&
      document.activeElement === this.stage
    ) {
      ev.preventDefault();
      if (ev.key === 'ArrowRight') this.next();
      else this.prev();
    }
  };

  connectedCallback(): void {
    this.stage = this.querySelector('[data-rw-stage]') as HTMLElement;
    this.actorsEl = this.querySelector('[data-rw-actors]') as HTMLElement;
    this.heroesEl = this.querySelector('[data-rw-heroes]') as HTMLElement;
    this.panelEl = this.querySelector('.rw__panel') as HTMLElement;
    this.liveEl = this.querySelector('[data-rw-live]');
    this.piecesEl = this.querySelector('[data-rw-pieces]');
    this.autoBtn = this.querySelector('[data-rw-auto]');
    this.cursorEl = this.querySelector('[data-rw-cursor]');
    this.lbEl = this.querySelector('[data-rw-lb]');
    this.lbStageEl = this.querySelector('[data-rw-lb-stage]');
    this.lbKickerEl = this.querySelector('[data-rw-lb-kicker]');
    this.lbNameEl = this.querySelector('[data-rw-lb-name]');

    if (!this.stage || !this.actorsEl || !this.heroesEl) return;

    this.reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    this.enableBlur = this.dataset.blur !== 'false';
    this.speedMs = Math.max(1000, Number(this.dataset.speed || 5000));
    this.autoplayEnabled = this.dataset.autoplay !== 'false';

    this.heroes = Array.from(this.querySelectorAll<HTMLElement>('[data-rw-hero]'));
    this.ticks = Array.from(this.querySelectorAll<HTMLButtonElement>('[data-rw-tick]'));
    this.panels = Array.from(this.querySelectorAll<HTMLElement>('[data-rw-panel]'));

    this.setupBodies();
    this.setupModelImages(this);
    this.probeFeet();
    this.initPickers();
    this.setupCursor();
    this.bindEvents();

    // Intro setup
    this.classList.add('rw--js');
    const startOffset = this.reducedMotion ? 0 : 1.15;
    this.target = 0;
    this.cur = -startOffset;
    this.vel = 0;
    for (const b of this.bodies) {
      const initPlace = b.index + startOffset;
      b.x = initPlace;
      b.g = initPlace;
      b.prevGoal = initPlace;
    }

    this.measure();
    this.setIndex(0, true);
    this.renderAll();

    if (this.reducedMotion) {
      this.classList.add('is-revealed');
      this.setStill(true);
      this.renderAll();
    } else {
      this.revealIo = new IntersectionObserver(
        (entries) => {
          if (entries.some((e) => e.isIntersecting)) {
            this.revealIo?.disconnect();
            this.revealIo = null;
            requestAnimationFrame(() => {
              requestAnimationFrame(() => {
                this.classList.add('is-revealed');
                this.kick();
                if (this.autoplayEnabled && !this.engaged) {
                  this.play(true);
                }
              });
            });
          }
        },
        { threshold: 0, rootMargin: '0px 0px -22% 0px' }
      );
      this.revealIo.observe(this);
    }

    this.visIo = new IntersectionObserver(
      (entries) => {
        const nextVis = entries.some((e) => e.isIntersecting);
        if (nextVis !== this.visible) {
          this.visible = nextVis;
          if (this.visible) {
            this.lastTs = 0;
            this.kick();
            if (this.playing) this.scheduleAutoplay();
          } else {
            this.stopLoop();
            this.clearAutoTimer();
          }
        }
      },
      { threshold: 0 }
    );
    this.visIo.observe(this);

    this.stageRo = new ResizeObserver(() => this.measure());
    this.stageRo.observe(this.stage);
  }

  disconnectedCallback(): void {
    this.stopLoop();
    this.clearAutoTimer();
    if (this.resizeTimer !== null) window.clearTimeout(this.resizeTimer);
    if (this.wheelLockTimer !== null) window.clearTimeout(this.wheelLockTimer);
    if (this.cursorRaf !== null) cancelAnimationFrame(this.cursorRaf);
    if (this.lbCloseTimer !== null) window.clearTimeout(this.lbCloseTimer);

    this.revealIo?.disconnect();
    this.visIo?.disconnect();
    this.stageRo?.disconnect();

    window.removeEventListener('resize', this.onWinResize);
    document.removeEventListener('visibilitychange', this.onDocVisChange);
    this.removeEventListener('keydown', this.onKeyDown);

    this.closeSheet();
    this.sheetHost?.remove();
    this.sheetHost = null;
  }

  private setupBodies(): void {
    const originals = Array.from(this.actorsEl.querySelectorAll<HTMLElement>('[data-rw-model]'));
    // Clone originals 0..5 into 6..11
    const neededCopies = Math.ceil(BODY_COUNT / LOOK_COUNT) - 1;
    for (let copy = 0; copy < neededCopies; copy++) {
      originals.forEach((orig, idx) => {
        const clone = orig.cloneNode(true) as HTMLElement;
        const bodyIdx = (copy + 1) * LOOK_COUNT + idx;
        clone.dataset.index = String(bodyIdx);
        clone.setAttribute('data-rw-clone', '');
        clone.querySelectorAll<HTMLImageElement>('[data-model-image]').forEach((img) => {
          img.loading = 'lazy';
        });
        this.actorsEl.appendChild(clone);
      });
    }

    const allBodies = Array.from(this.actorsEl.querySelectorAll<HTMLElement>('[data-rw-model]'));
    this.bodies = allBodies.map((el, i) => ({
      el,
      hit: el.querySelector<HTMLButtonElement>('[data-rw-go]'),
      index: i,
      lookIndex: i % LOOK_COUNT,
      w: 0,
      x: i,
      g: i,
      v: 0,
      from: i,
      onTrip: false,
      prevGoal: i,
      blurStr: '',
    }));
  }

  private setupModelImages(root: ParentNode): void {
    root.querySelectorAll<HTMLImageElement>('[data-model-image]').forEach((img) => {
      const mark = () => img.classList.add('is-decoded');
      const tryDecode = () => {
        if (typeof img.decode === 'function') {
          img.decode().then(mark, () => {
            if (img.naturalWidth > 0) mark();
          });
        } else if (img.naturalWidth > 0) {
          mark();
        }
      };

      if (img.complete && img.naturalWidth > 0) {
        tryDecode();
      } else {
        img.addEventListener('load', tryDecode, { once: true });
      }
    });
  }

  private probeFeet(): void {
    this.heroes.forEach((hero, lookIdx) => {
      const probeUrl = hero.dataset.probe;
      if (!probeUrl) return;
      const img = new Image();
      img.crossOrigin = 'anonymous';
      img.onload = () => {
        try {
          if (!img.naturalWidth || !img.naturalHeight) return;
          const w = 48;
          const h = Math.max(1, Math.round((w * img.naturalHeight) / img.naturalWidth));
          const canvas = document.createElement('canvas');
          canvas.width = w;
          canvas.height = h;
          const ctx = canvas.getContext('2d');
          if (!ctx) return;
          ctx.drawImage(img, 0, 0, w, h);
          const { data } = ctx.getImageData(0, 0, w, h);
          const frac = computeFootFractionFromAlpha(data, w, h, 40);
          this.footByLook[lookIdx] = frac;
          const val = frac.toFixed(4);
          hero.style.setProperty('--rw-foot', val);
          for (const b of this.bodies) {
            if (b.lookIndex === lookIdx) {
              b.el.style.setProperty('--rw-foot', val);
            }
          }
        } catch {
          // Tainted canvas keeps offset 0
        }
      };
      img.src = probeUrl;
    });
  }

  private setupCursor(): void {
    this.hasFineCursor = window.matchMedia('(hover: hover) and (pointer: fine)').matches;
    if (!this.hasFineCursor) {
      this.cursorEl?.remove();
      this.cursorEl = null;
      return;
    }
    this.classList.add('rw--cursor');
  }

  private bindEvents(): void {
    window.addEventListener('resize', this.onWinResize);
    document.addEventListener('visibilitychange', this.onDocVisChange);
    this.addEventListener('keydown', this.onKeyDown);

    // Click capture to suppress accidental click right after drag
    this.addEventListener(
      'click',
      (ev) => {
        if (performance.now() < this.suppressClickUntil) {
          ev.preventDefault();
          ev.stopPropagation();
        }
      },
      true
    );

    // Delegated click handler on section
    this.addEventListener('click', (ev) => this.routeClick(ev));

    // Panel interactions: engage + option change + hover hot-linking
    if (this.panelEl) {
      this.panelEl.addEventListener('pointerenter', (ev) => {
        if (ev.pointerType === 'mouse') {
          this.panelHover = true;
        }
      });
      this.panelEl.addEventListener('pointerleave', (ev) => {
        if (ev.pointerType === 'mouse') {
          this.panelHover = false;
          if (this.playing) this.restartAutoplayBar();
        }
      });
      this.panelEl.addEventListener('click', (ev) => {
        const target = ev.target as HTMLElement | null;
        if (target?.closest('button, a, input, select, label')) {
          this.engage();
        }
      });
      this.panelEl.addEventListener('change', (ev) => {
        this.engage();
        this.handleOptionChange(ev);
      });
      this.panelEl.addEventListener('pointerover', (ev) => {
        if (ev.pointerType !== 'mouse') return;
        const card = (ev.target as HTMLElement | null)?.closest<HTMLElement>('[data-rw-card]');
        if (card) {
          this.hot(card.dataset.rwCard || null, false);
        }
      });
      this.panelEl.addEventListener('pointerout', (ev) => {
        if (ev.pointerType !== 'mouse') return;
        const card = (ev.target as HTMLElement | null)?.closest<HTMLElement>('[data-rw-card]');
        if (!card) return;
        const rel = ev.relatedTarget as Node | null;
        if (!rel || !card.contains(rel)) {
          this.hot(null);
        }
      });
    }

    // Stage drag & custom cursor
    this.stage.addEventListener('pointerdown', (ev) => this.onStagePointerDown(ev));
    this.stage.addEventListener('pointermove', (ev) => this.onStagePointerMove(ev));
    this.stage.addEventListener('pointerup', (ev) => this.onStagePointerUp(ev));
    this.stage.addEventListener('pointercancel', (ev) => this.onStagePointerUp(ev));
    this.stage.addEventListener('pointerleave', () => {
      if (!this.cursorEl) return;
      this.cursorEl.classList.remove('is-on', 'is-link', 'is-view');
      this.cursorActive = false;
    });

    // Trackpad horizontal wheel
    this.stage.addEventListener(
      'wheel',
      (ev) => {
        if (Math.abs(ev.deltaX) > Math.abs(ev.deltaY) && Math.abs(ev.deltaX) > 0) {
          ev.preventDefault();
          if (this.wheelLocked) return;
          this.wheelAcc += ev.deltaX;
          if (Math.abs(this.wheelAcc) > 45) {
            if (this.wheelAcc > 0) this.next();
            else this.prev();
            this.wheelAcc = 0;
            this.wheelLocked = true;
            if (this.wheelLockTimer !== null) window.clearTimeout(this.wheelLockTimer);
            this.wheelLockTimer = window.setTimeout(() => {
              this.wheelLocked = false;
              this.wheelAcc = 0;
            }, 520);
          }
        }
      },
      { passive: false }
    );
  }

  private routeClick(ev: Event): void {
    const target = ev.target as HTMLElement | null;
    if (!target) return;

    // 1. pick-close
    if (target.closest('[data-rw-pick-close]')) {
      ev.preventDefault();
      const card = this.activeSheetCard;
      this.closeSheet();
      card?.querySelector<HTMLButtonElement>('[data-rw-add]')?.focus({ preventScroll: true });
      return;
    }

    // 2. popup close button
    if (target.closest('[data-rw-zoom-close]')) {
      ev.preventDefault();
      this.closePopup();
      return;
    }

    // 3. click on popup backdrop or popup stage beside the model
    if (
      this.zoomed &&
      (target.matches('[data-rw-lb]') ||
        target.matches('[data-rw-lb-stage]') ||
        (target.closest('[data-rw-lb-stage]') && !target.closest('.rw__lb-model')))
    ) {
      ev.preventDefault();
      this.closePopup();
      return;
    }

    // 4. [data-rw-zoom] opens the popup
    if (target.closest('[data-rw-zoom]')) {
      ev.preventDefault();
      this.openPopup();
      return;
    }

    // 5. next
    if (target.closest('[data-rw-next]')) {
      ev.preventDefault();
      this.next();
      return;
    }

    // 6. prev
    if (target.closest('[data-rw-prev]')) {
      ev.preventDefault();
      this.prev();
      return;
    }

    // 7. tick
    const tickBtn = target.closest<HTMLButtonElement>('[data-rw-tick]');
    if (tickBtn) {
      ev.preventDefault();
      const i = Number(tickBtn.dataset.rwTick);
      if (Number.isFinite(i)) this.go(i);
      return;
    }

    // 8. autoplay toggle
    if (target.closest('[data-rw-auto]')) {
      ev.preventDefault();
      if (!this.playing) {
        this.engaged = false;
        this.play(true);
      } else {
        this.play(false);
      }
      return;
    }

    // 9. pin
    const pinBtn = target.closest<HTMLButtonElement>('[data-rw-pin]');
    if (pinBtn) {
      ev.preventDefault();
      this.engage();
      this.hot(pinBtn.dataset.rwPin || null, true);
      return;
    }

    // 10. queue body [data-rw-go]
    const hitBtn = target.closest<HTMLButtonElement>('[data-rw-go]');
    if (hitBtn) {
      ev.preventDefault();
      const modelEl = hitBtn.closest<HTMLElement>('[data-rw-model]');
      const bodyIdx = Number(modelEl?.dataset.index);
      if (Number.isFinite(bodyIdx)) {
        const k =
          this.mode === 'ring'
            ? ringSlotRank(bodyIdx, this.target)
            : wrapMod(bodyIdx - Math.round(this.target), BODY_COUNT);
        if (k === 0) {
          this.openPopup();
        } else if (Math.abs(k) < 6) {
          this.moveTo(Math.round(this.target) + k);
        }
      }
      return;
    }

    // 11. size confirm
    const confirmBtn = target.closest<HTMLButtonElement>('[data-rw-confirm]');
    if (confirmBtn) {
      ev.preventDefault();
      this.confirmCard(confirmBtn);
      return;
    }

    // 12. plus button
    const addBtn = target.closest<HTMLButtonElement>('[data-rw-add]');
    if (addBtn) {
      ev.preventDefault();
      const card = addBtn.closest<HTMLElement>('[data-rw-card]');
      if (card) this.togglePicker(card);
      return;
    }

    // 13. add full look
    const allBtn = target.closest<HTMLButtonElement>('[data-rw-all]');
    if (allBtn) {
      ev.preventDefault();
      const panel = allBtn.closest<HTMLElement>('[data-rw-panel]');
      if (panel) this.addFullLook(panel, allBtn);
    }
  }

  // --- Measurement & Layout ---

  measure(): void {
    const winW = window.innerWidth;
    const winH = window.innerHeight;
    const wasMobile = this.isMobile;
    this.isMobile = winW <= 749;

    if (!this.latchedVh || winW !== this.lastWinW || Math.abs(winH - this.latchedVh) >= 160) {
      this.latchedVh = winH;
      this.lastWinW = winW;
    }

    let headerHeight = 0;
    document
      .querySelectorAll<HTMLElement>(
        '.shopify-section-group-header-group, #shopify-section-header, #shopify-section-announcement-bar'
      )
      .forEach((el) => {
        if (el.contains(this)) return;
        const style = getComputedStyle(el);
        if (style.display === 'none' || style.visibility === 'hidden') return;
        headerHeight += el.getBoundingClientRect().height;
      });

    const mheightVh = Number(this.dataset.mheightVh || 109);
    const frameH = computeFrameHeight(
      this.isMobile,
      this.isMobile ? this.latchedVh : winH,
      headerHeight,
      mheightVh
    );
    this.style.setProperty('--rw-frame-h', `${Math.round(frameH)}px`);

    const nextMode: RunwayMode = this.isMobile
      ? ((this.dataset.mstyle as RunwayMode) || 'classic')
      : ((this.dataset.style as RunwayMode) || 'ring');

    if (nextMode !== this.mode) {
      this.mode = nextMode;
      // Re-sync classic bodies when switching mode
      if (this.mode === 'classic') {
        for (const b of this.bodies) {
          const goal = wrapMod(b.index - this.target, BODY_COUNT);
          b.x = goal;
          b.g = goal;
          b.v = 0;
          b.prevGoal = goal;
          b.onTrip = false;
        }
      }
    }

    if (wasMobile && !this.isMobile && this.activeSheetCard) {
      this.closeSheet();
    }

    const rect = this.stage.getBoundingClientRect();
    this.W = rect.width;
    this.H = rect.height;

    if (this.W > 0 && this.H > 0) {
      const m = computeStageMetrics(this.mode, this.isMobile, this.W, this.H);
      this.fs = m.fs;
      this.unit = m.unit;

      this.stage.style.setProperty('--rw-fs', String(m.fs));
      this.stage.style.setProperty('--rw-model-h', `${m.modelH}px`);
      this.stage.style.setProperty('--rw-hx', `${m.hx}px`);
      this.stage.style.setProperty('--rw-hy', `${m.hy}px`);
      this.style.setProperty('--rw-ax', `${((m.hx / this.W) * 100).toFixed(2)}%`);

      for (const b of this.bodies) {
        b.w = b.el.offsetWidth || m.modelH * 0.5625;
      }
    }

    if (this.zoomed) {
      this.sizePopupModel();
    }

    this.renderAll();
  }

  // --- Loop & Rendering ---

  private setStill(value: boolean): void {
    if (this.still === value) return;
    this.still = value;
    this.classList.toggle('rw--still', value);
  }

  private kick(): void {
    if (this.rafId !== null || !this.visible || document.hidden) return;
    this.lastTs = 0;
    this.rafId = requestAnimationFrame((ts) => this.tickFrame(ts));
  }

  private stopLoop(): void {
    if (this.rafId !== null) {
      cancelAnimationFrame(this.rafId);
      this.rafId = null;
    }
  }

  private tickFrame(ts: number): void {
    this.rafId = null;
    if (!this.visible || document.hidden) return;

    const dt = this.lastTs ? Math.min(0.034, (ts - this.lastTs) / 1000) : 1 / 60;
    this.lastTs = ts;

    if (this.reducedMotion) {
      this.cur = this.target;
      this.vel = 0;
      for (const b of this.bodies) {
        const goal = wrapMod(b.index - this.target, BODY_COUNT);
        b.x = goal;
        b.g = goal;
        b.v = 0;
        b.onTrip = false;
        b.prevGoal = goal;
      }
      this.setStill(true);
      this.renderAll();
      return;
    }

    let keepGoing = this.dragging;

    if (this.mode === 'ring') {
      if (this.dragging) {
        const res = stepSpring(this.cur, this.target, this.vel, dt);
        this.cur = res.cur;
        this.vel = res.vel;
        this.setStill(false);
      } else {
        const res = stepSpring(this.cur, this.target, this.vel, dt);
        this.cur = res.cur;
        this.vel = res.vel;
        if (res.settled) {
          this.setStill(true);
        } else {
          this.setStill(false);
          keepGoing = true;
        }
      }
    } else {
      // Classic mode: per-body follow lag + spring
      let allSettled = !this.dragging;
      for (const b of this.bodies) {
        const goal = wrapMod(b.index - this.target, BODY_COUNT);
        if (!this.dragging && Math.abs(goal - b.prevGoal) > BODY_COUNT / 2) {
          b.onTrip = true;
          b.from = b.x;
        }
        b.prevGoal = goal;

        const tau = this.dragging
          ? 0.016
          : b.onTrip
            ? 0.1
            : 0.03 + 0.04 * Math.min(goal, 4);

        b.g += (goal - b.g) * (1 - Math.exp(-dt / tau));
        const res = stepSpring(b.x, b.g, b.v, dt, 0.0006);
        b.x = res.cur;
        b.v = res.vel;

        if (b.onTrip && Math.abs(b.x - goal) < 0.02) {
          b.onTrip = false;
        }

        if (!res.settled || Math.abs(b.g - goal) > 0.0006 || b.onTrip) {
          allSettled = false;
        } else {
          b.x = goal;
          b.g = goal;
        }
      }

      this.cur = this.target;
      if (allSettled) {
        this.setStill(true);
      } else {
        this.setStill(false);
        keepGoing = true;
      }
    }

    this.renderAll();

    if (keepGoing) {
      this.rafId = requestAnimationFrame((nextTs) => this.tickFrame(nextTs));
    }
  }

  private renderAll(): void {
    if (this.W <= 0 || this.H <= 0) return;

    if (this.mode === 'ring') {
      for (const b of this.bodies) {
        const pose = computeRingPose(
          b.index,
          this.cur,
          this.W,
          this.H,
          this.isMobile,
          this.fs,
          this.still,
          this.enableBlur
        );
        this.put(b, pose.x, pose.bottom, pose.scale, pose.opacity, pose.blur, pose.z);
      }
    } else {
      for (const b of this.bodies) {
        const goal = wrapMod(b.index - this.target, BODY_COUNT);
        const pose = computeClassicPose(
          b.x,
          goal,
          b.from,
          b.onTrip,
          this.W,
          this.isMobile,
          this.still,
          this.enableBlur
        );
        this.put(b, pose.x, pose.bottom, pose.scale, pose.opacity, pose.blur, pose.z);
      }
    }
  }

  private put(
    b: BodyState,
    x: number,
    bottom: number,
    scale: number,
    opacity: number,
    blur: number,
    z: number
  ): void {
    const halfW = (b.w * scale) / 2;
    let op = opacity;
    if (x + halfW < -4 || x - halfW > this.W + 4) {
      op = 0;
    }

    b.el.style.transform = `translate3d(${x.toFixed(2)}px, ${(-bottom).toFixed(2)}px, 0) translateX(-50%) scale(${scale.toFixed(4)})`;
    b.el.style.opacity = op.toFixed(3);
    b.el.style.zIndex = String(z);
    b.el.style.visibility = op < 0.01 ? 'hidden' : '';
    b.el.style.pointerEvents = op < 0.5 ? 'none' : '';

    const bRounded = Math.round(blur * 10) / 10;
    const nextBlur = bRounded > 0.05 ? `blur(${bRounded}px)` : '';
    if (nextBlur !== b.blurStr) {
      b.el.style.filter = nextBlur;
      b.blurStr = nextBlur;
    }
  }

  // --- Navigation & Autoplay ---

  next(): void {
    this.moveTo(Math.round(this.target) + 1);
  }

  prev(): void {
    this.moveTo(Math.round(this.target) - 1);
  }

  go(i: number): void {
    const targetIdx = wrapMod(i, LOOK_COUNT);
    const d = shortestLoopDelta(this.index, targetIdx, LOOK_COUNT);
    this.moveTo(Math.round(this.target) + d);
  }

  moveTo(T: number): void {
    this.target = T;
    this.setStill(false);
    this.setIndex(wrapMod(T, LOOK_COUNT), false);
    this.kick();
  }

  private setIndex(i: number, silent: boolean): void {
    const prevIdx = this.index;
    this.index = wrapMod(i, LOOK_COUNT);

    // Body accessibility
    for (const b of this.bodies) {
      const k =
        this.mode === 'ring'
          ? ringSlotRank(b.index, this.target)
          : wrapMod(b.index - Math.round(this.target), BODY_COUNT);
      const reachable =
        this.mode === 'ring' ? k !== 0 && Math.abs(k) <= 2 : k !== 0 && k <= 3;

      if (reachable) {
        b.el.removeAttribute('aria-hidden');
        if (b.hit) {
          b.hit.tabIndex = 0;
          b.hit.setAttribute('aria-hidden', 'false');
        }
      } else {
        b.el.setAttribute('aria-hidden', 'true');
        if (b.hit) {
          b.hit.tabIndex = -1;
          b.hit.setAttribute('aria-hidden', 'true');
        }
      }
    }

    if (!silent) {
      if (this.zoomed) this.closePopup();
      if (this.activeSheetCard) this.closeSheet();
    }

    this.style.setProperty('--rw-progress', ((this.index + 1) / LOOK_COUNT).toFixed(3));

    // Heroes
    this.heroes.forEach((hero, idx) => {
      const isOn = idx === this.index;
      const was = !isOn && idx === prevIdx && !silent;
      hero.classList.toggle('is-on', isOn);
      hero.classList.toggle('was', was);
      hero.setAttribute('aria-hidden', isOn ? 'false' : 'true');
      const zoomBtn = hero.querySelector<HTMLButtonElement>('[data-rw-zoom]');
      if (zoomBtn) zoomBtn.tabIndex = isOn ? 0 : -1;
    });

    // Ticks
    this.ticks.forEach((tick, idx) => {
      const active = idx === this.index;
      tick.setAttribute('aria-current', active ? 'true' : 'false');
      tick.classList.toggle('is-past', idx < this.index);
    });

    // Panels & pieces label
    const activePanel = this.panels[this.index];
    this.panels.forEach((p, idx) => {
      p.hidden = idx !== this.index;
      if (!silent) p.classList.remove('is-in');
    });

    if (!silent && activePanel) {
      void activePanel.offsetWidth;
      activePanel.classList.add('is-in');
    }

    const tpl = activePanel?.querySelector<HTMLTemplateElement>('[data-rw-pieces-text]');
    if (this.piecesEl && tpl) {
      this.piecesEl.textContent = tpl.content.textContent || tpl.innerHTML;
      if (!silent) {
        this.piecesEl.classList.remove('is-swap');
        void this.piecesEl.offsetWidth;
        this.piecesEl.classList.add('is-swap');
      }
    }

    if (!silent) {
      // Sweep
      if (!this.reducedMotion) {
        this.stage.classList.remove('is-sweep');
        void this.stage.offsetWidth;
        this.stage.classList.add('is-sweep');
      }

      // Live announcement
      const activeHero = this.heroes[this.index];
      if (this.liveEl && activeHero) {
        this.liveEl.textContent = activeHero.dataset.label || '';
      }

      this.hot(null);
      if (this.playing) {
        this.restartAutoplayBar();
        this.scheduleAutoplay();
      }
    }
  }

  private play(on: boolean): void {
    if (on && this.reducedMotion) return;
    this.playing = on;
    this.classList.toggle('is-playing', on);
    if (this.autoBtn) {
      this.autoBtn.setAttribute('aria-pressed', on ? 'true' : 'false');
    }
    if (on) {
      this.restartAutoplayBar();
      this.scheduleAutoplay();
    } else {
      this.clearAutoTimer();
      this.ticks.forEach((t) => t.classList.remove('is-run'));
    }
  }

  private engage(): void {
    this.engaged = true;
    if (this.playing) this.play(false);
  }

  private restartAutoplayBar(): void {
    this.ticks.forEach((t) => t.classList.remove('is-run'));
    const curTick = this.ticks[this.index];
    if (!curTick || !this.playing) return;
    void curTick.offsetWidth;
    curTick.classList.add('is-run');
  }

  private clearAutoTimer(): void {
    if (this.autoTimer !== null) {
      window.clearTimeout(this.autoTimer);
      this.autoTimer = null;
    }
  }

  private scheduleAutoplay(): void {
    this.clearAutoTimer();
    if (!this.playing) return;
    this.autoTimer = window.setTimeout(() => {
      if (!this.playing) return;
      if (
        this.visible &&
        !this.dragging &&
        !document.hidden &&
        !this.panelHover &&
        !this.zoomed &&
        !this.engaged
      ) {
        this.next();
      } else {
        this.restartAutoplayBar();
        this.scheduleAutoplay();
      }
    }, this.speedMs);
  }

  // --- Drag & Cursor ---

  private onStagePointerDown(ev: PointerEvent): void {
    if (ev.pointerType === 'mouse' && ev.button !== 0) return;
    const targetEl = ev.target as HTMLElement | null;
    if (targetEl?.closest('[data-rw-pin]')) return;

    this.dragPointerId = ev.pointerId;
    this.dragStartX = ev.clientX;
    this.dragStartY = ev.clientY;
    this.dragStartTarget = this.target;
    this.dragAbandoned = false;
    this.dragSamples = [{ x: ev.clientX, time: performance.now() }];
  }

  private onStagePointerMove(ev: PointerEvent): void {
    if (ev.pointerType === 'mouse' && this.hasFineCursor && this.cursorEl) {
      this.updateCursorTarget(ev);
    }

    if (this.dragPointerId !== ev.pointerId || this.dragAbandoned) return;

    if (ev.pointerType === 'mouse' && (ev.buttons & 1) === 0) {
      this.onStagePointerUp(ev);
      return;
    }

    const dx = ev.clientX - this.dragStartX;
    const dy = ev.clientY - this.dragStartY;

    if (!this.dragging) {
      if (Math.abs(dy) > 10 && Math.abs(dy) >= Math.abs(dx)) {
        this.dragAbandoned = true;
        this.dragPointerId = null;
        return;
      }
      if (Math.abs(dx) > 8 && Math.abs(dx) > 1.2 * Math.abs(dy)) {
        this.dragging = true;
        this.classList.add('is-dragging');
        this.setStill(false);
        try {
          this.stage.setPointerCapture(ev.pointerId);
        } catch {
          // ignore
        }
      }
    }

    if (this.dragging) {
      this.target = this.dragStartTarget - dx / this.unit;
      this.dragSamples.push({ x: ev.clientX, time: performance.now() });
      if (this.dragSamples.length > 6) this.dragSamples.shift();
      this.kick();
    }
  }

  private onStagePointerUp(ev: PointerEvent): void {
    if (this.dragPointerId !== ev.pointerId) return;
    const wasDragging = this.dragging;
    const dx = ev.clientX - this.dragStartX;

    this.dragPointerId = null;
    this.dragging = false;
    this.classList.remove('is-dragging');

    if (this.stage.hasPointerCapture?.(ev.pointerId)) {
      try {
        this.stage.releasePointerCapture(ev.pointerId);
      } catch {
        // ignore
      }
    }

    if (!wasDragging) return;

    this.suppressClickUntil = performance.now() + 60;

    let vx = 0;
    if (this.dragSamples.length >= 2) {
      const first = this.dragSamples[0];
      const last = this.dragSamples[this.dragSamples.length - 1];
      const dt = last.time - first.time;
      if (dt > 0) vx = (last.x - first.x) / dt;
    }

    const sign = -1;
    const from = Math.round(this.dragStartTarget);

    if (this.isMobile) {
      if (Math.abs(dx) > 30 || Math.abs(vx) > 0.3) {
        this.moveTo(from + sign * (dx > 0 ? 1 : -1));
      } else {
        this.moveTo(from);
      }
    } else {
      let nextIdx = Math.round(this.target + (sign * vx * 160) / this.unit);
      if (nextIdx === from && Math.abs(vx) > 0.3) {
        nextIdx += sign * (vx > 0 ? 1 : -1);
      }
      nextIdx = Math.max(from - 2, Math.min(from + 2, nextIdx));
      this.moveTo(nextIdx);
    }
  }

  private updateCursorTarget(ev: PointerEvent): void {
    if (!this.cursorEl) return;
    const rect = this.stage.getBoundingClientRect();
    this.cursorTx = ev.clientX - rect.left;
    this.cursorTy = ev.clientY - rect.top;

    const targetEl = ev.target as HTMLElement | null;
    const isLink = !this.dragging && Boolean(targetEl?.closest('.rw__pin, .rw__hit'));
    const isView = !this.dragging && !isLink && Boolean(targetEl?.closest('.rw__zoom'));

    this.cursorEl.classList.toggle('is-link', isLink);
    this.cursorEl.classList.toggle('is-view', isView);

    if (!this.cursorActive) {
      this.cursorActive = true;
      this.cursorX = this.cursorTx;
      this.cursorY = this.cursorTy;
      this.cursorEl.style.transform = `translate3d(${this.cursorX}px, ${this.cursorY}px, 0)`;
      this.cursorEl.classList.add('is-on');
    }

    if (this.cursorRaf === null) {
      this.cursorRaf = requestAnimationFrame(() => this.stepCursor());
    }
  }

  private stepCursor(): void {
    this.cursorRaf = null;
    if (!this.cursorEl || !this.cursorActive) return;

    const factor = this.reducedMotion ? 1 : 0.18;
    this.cursorX += (this.cursorTx - this.cursorX) * factor;
    this.cursorY += (this.cursorTy - this.cursorY) * factor;
    this.cursorEl.style.transform = `translate3d(${this.cursorX.toFixed(2)}px, ${this.cursorY.toFixed(2)}px, 0)`;

    if (
      Math.abs(this.cursorTx - this.cursorX) >= 0.2 ||
      Math.abs(this.cursorTy - this.cursorY) >= 0.2
    ) {
      this.cursorRaf = requestAnimationFrame(() => this.stepCursor());
    }
  }

  // --- Hot linking ---

  private hot(n: string | null, reveal = false): void {
    this.querySelectorAll('.is-hot').forEach((el) => el.classList.remove('is-hot'));
    if (!n) return;

    const pinScope = this.zoomed && this.lbStageEl ? this.lbStageEl : this.heroes[this.index];
    const pin = pinScope?.querySelector<HTMLElement>(`[data-rw-pin="${n}"]`);
    pin?.classList.add('is-hot');

    const activePanel = this.panels[this.index];
    const card = activePanel?.querySelector<HTMLElement>(`[data-rw-card="${n}"]`);
    card?.classList.add('is-hot');

    if (reveal && card) {
      this.revealCard(card);
    }
  }

  private revealCard(card: HTMLElement): void {
    const list = card.closest<HTMLElement>('.rw__items');
    if (!list) return;
    const behavior: ScrollBehavior = this.reducedMotion ? 'auto' : 'smooth';

    if (list.scrollWidth > list.clientWidth + 2) {
      const listRect = list.getBoundingClientRect();
      const cardRect = card.getBoundingClientRect();
      const left = list.scrollLeft + (cardRect.left - listRect.left - 20);
      list.scrollTo({ left: Math.max(0, left), behavior });
    } else if (list.scrollHeight > list.clientHeight + 2) {
      const top = card.offsetTop - list.offsetTop - 12;
      list.scrollTo({ top: Math.max(0, top), behavior });
    } else {
      const rect = card.getBoundingClientRect();
      if (rect.top < 0 || rect.bottom > window.innerHeight - 140) {
        window.scrollBy({
          top: rect.top - 0.3 * window.innerHeight,
          behavior,
        });
      }
    }
  }

  // --- View Look Popup (Lightbox) ---

  private openPopup(): void {
    if (this.zoomed || !this.lbEl || !this.lbStageEl) return;
    const hero = this.heroes[this.index];
    if (!hero) return;

    this.engage();
    this.hot(null);

    if (this.lbCloseTimer !== null) {
      window.clearTimeout(this.lbCloseTimer);
      this.lbCloseTimer = null;
    }

    const heroShadow = hero.querySelector('.rw__shadow');
    const heroFigure = hero.querySelector('.rw__figure');
    if (!heroFigure) return;

    const wrapper = document.createElement('div');
    wrapper.className = 'rw__lb-model';
    if (heroShadow) wrapper.appendChild(heroShadow.cloneNode(true));

    const figClone = heroFigure.cloneNode(true) as HTMLElement;
    figClone.querySelector('[data-rw-zoom]')?.remove();
    figClone.querySelectorAll<HTMLButtonElement>('[data-rw-pin]').forEach((p) => {
      p.tabIndex = 0;
    });

    const foot = this.footByLook[this.index] || 0;
    wrapper.style.setProperty('--rw-foot', foot.toFixed(4));

    wrapper.appendChild(figClone);
    this.lbStageEl.replaceChildren(wrapper);

    figClone.querySelectorAll<HTMLImageElement>('[data-model-image]').forEach((img) => {
      img.loading = 'eager';
      img.classList.add('is-decoded');
    });

    const word = this.lbEl.dataset.word || 'Look';
    if (this.lbKickerEl) {
      this.lbKickerEl.textContent = `${word} ${String(this.index + 1).padStart(2, '0')}`;
    }
    if (this.lbNameEl) {
      this.lbNameEl.textContent = hero.dataset.name || '';
    }

    this.zoomed = true;
    this.classList.add('rw--zoom');
    this.lbEl.setAttribute('aria-hidden', 'false');

    const modelH = this.sizePopupModel();
    figClone.querySelectorAll<HTMLImageElement>('[data-model-image]').forEach((img) => {
      img.sizes = `${Math.round(modelH * 0.5625)}px`;
    });

    if (!this.reducedMotion) {
      const a = heroFigure.getBoundingClientRect();
      const b = figClone.getBoundingClientRect();
      if (a.height > 0 && b.height > 0) {
        wrapper.style.transition = 'none';
        wrapper.style.transformOrigin = '0 100%';
        wrapper.style.transform = `translate3d(${a.left - b.left}px, ${a.bottom - b.bottom}px, 0) scale(${a.height / b.height})`;
        void wrapper.offsetWidth;
        wrapper.style.transition = '';
        wrapper.style.transform = '';
      }
    }

    const closeBtn = this.lbEl.querySelector<HTMLButtonElement>('[data-rw-zoom-close]');
    closeBtn?.focus({ preventScroll: true });
  }

  private sizePopupModel(): number {
    if (!this.lbStageEl) return 560;
    const rect = this.lbStageEl.getBoundingClientRect();
    const h = Math.max(160, Math.min(rect.height, rect.width / 0.5625));
    const model = this.lbStageEl.querySelector<HTMLElement>('.rw__lb-model');
    if (model) {
      model.style.setProperty('--rw-model-h', `${Math.round(h)}px`);
    }
    return h;
  }

  private closePopup(): void {
    if (!this.zoomed || !this.lbEl || !this.lbStageEl) return;
    this.zoomed = false;

    const wrapper = this.lbStageEl.querySelector<HTMLElement>('.rw__lb-model');
    const heroFigure = this.heroes[this.index]?.querySelector('.rw__figure');
    const lbFigure = wrapper?.querySelector('.rw__figure');

    if (!this.reducedMotion && wrapper && heroFigure && lbFigure) {
      const a = heroFigure.getBoundingClientRect();
      const b = lbFigure.getBoundingClientRect();
      if (a.height > 0 && b.height > 0) {
        wrapper.style.transformOrigin = '0 100%';
        wrapper.style.transform = `translate3d(${a.left - b.left}px, ${a.bottom - b.bottom}px, 0) scale(${a.height / b.height})`;
      }
    }

    const activeInside = document.activeElement && this.lbEl.contains(document.activeElement);
    this.classList.remove('rw--zoom');
    this.lbEl.setAttribute('aria-hidden', 'true');
    if (activeInside) {
      this.stage.focus({ preventScroll: true });
    }

    const delay = this.reducedMotion ? 0 : 950;
    this.lbCloseTimer = window.setTimeout(() => {
      if (!this.zoomed && this.lbStageEl) {
        this.lbStageEl.replaceChildren();
      }
      this.lbCloseTimer = null;
    }, delay);
  }

  // --- Pickers, Sheet & Bag ---

  private initPickers(): void {
    this.querySelectorAll<HTMLElement>('[data-rw-card]').forEach((card) => {
      const picker = card.querySelector<HTMLElement>('[data-rw-picker]');
      if (!picker) return;
      this.syncCardOptions(card, picker, false);
    });
  }

  private getCardVariants(picker: HTMLElement): CatalogVariant[] {
    const script = picker.querySelector<HTMLScriptElement>('[data-rw-variants]');
    if (!script) return [];
    try {
      const parsed = JSON.parse(script.textContent || '[]');
      return Array.isArray(parsed) ? parsed : [];
    } catch {
      return [];
    }
  }

  private syncCardOptions(card: HTMLElement, picker: HTMLElement, markTouched: boolean): void {
    const variants = this.getCardVariants(picker);
    const fieldsets = Array.from(picker.querySelectorAll<HTMLElement>('.rw__opt'));
    const selectedOptions: string[] = fieldsets.map((fs) => {
      const checked = fs.querySelector<HTMLInputElement>('input[type="radio"]:checked');
      return checked ? checked.value : '';
    });

    fieldsets.forEach((fs, optIdx) => {
      fs.querySelectorAll<HTMLElement>('.rw__pill').forEach((pill) => {
        const input = pill.querySelector<HTMLInputElement>('input[type="radio"]');
        if (!input) return;
        const avail = isOptionValueAvailable(variants, optIdx, input.value, selectedOptions);
        pill.classList.toggle('is-unavailable', !avail);
      });
    });

    const match = findMatchingVariant(variants, selectedOptions);
    const confirmBtn = picker.querySelector<HTMLButtonElement>('[data-rw-confirm]');
    const confirmLabel = picker.querySelector<HTMLElement>('[data-rw-confirm-label]');

    if (match && match.a) {
      card.dataset.selected = String(match.id);
      card.dataset.soldout = '0';
      if (confirmBtn) confirmBtn.disabled = false;
      if (confirmLabel) confirmLabel.textContent = confirmLabel.dataset.add || 'Add to bag';
    } else {
      card.dataset.selected = '';
      card.dataset.soldout = '1';
      if (confirmBtn) confirmBtn.disabled = true;
      if (confirmLabel) {
        confirmLabel.textContent = this.dataset.msgSoldout || 'Sold out';
      }
    }

    if (markTouched) {
      card.dataset.touched = '1';
    }
  }

  private handleOptionChange(ev: Event): void {
    const input = (ev.target as HTMLElement | null)?.closest<HTMLInputElement>(
      'input[data-rw-option]'
    );
    if (!input) return;
    const picker = input.closest<HTMLElement>('[data-rw-picker]');
    if (!picker) return;
    const card =
      this.activeSheetPicker === picker
        ? this.activeSheetCard
        : picker.closest<HTMLElement>('[data-rw-card]');
    if (!card) return;
    this.syncCardOptions(card, picker, true);
  }

  private getCardPicker(card: HTMLElement): HTMLElement | null {
    if (this.activeSheetCard === card && this.activeSheetPicker) {
      return this.activeSheetPicker;
    }
    return card.querySelector<HTMLElement>('[data-rw-picker]');
  }

  private togglePicker(card: HTMLElement, forceOpen?: boolean): void {
    if (card.classList.contains('is-added') || card.classList.contains('is-loading')) return;
    const picker = this.getCardPicker(card);
    if (!picker) return;

    const isOpen =
      this.isMobile ? this.activeSheetCard === card : !picker.hidden;
    const nextOpen = forceOpen !== undefined ? forceOpen : !isOpen;

    if (this.isMobile) {
      if (nextOpen) {
        this.openSheet(card, picker);
      } else {
        this.closeSheet();
      }
      return;
    }

    const addBtn = card.querySelector<HTMLButtonElement>('[data-rw-add]');
    if (nextOpen) {
      picker.hidden = false;
      card.classList.add('is-picking');
      addBtn?.setAttribute('aria-expanded', 'true');
      const checked = picker.querySelector<HTMLInputElement>('input[type="radio"]:checked');
      checked?.focus({ preventScroll: true });
      this.revealCard(card);
    } else {
      picker.hidden = true;
      card.classList.remove('is-picking');
      addBtn?.setAttribute('aria-expanded', 'false');
    }
  }

  private ensureSheetHost(): HTMLElement {
    if (this.sheetHost) return this.sheetHost;
    const host = document.createElement('div');
    host.className = 'rw-sheet-host';

    const scrim = document.createElement('button');
    scrim.type = 'button';
    scrim.className = 'rw__pick-scrim';
    scrim.setAttribute('data-rw-pick-close', '');
    scrim.tabIndex = -1;
    scrim.setAttribute('aria-hidden', 'true');
    host.appendChild(scrim);

    host.addEventListener('click', (ev) => this.routeClick(ev));
    host.addEventListener('change', (ev) => {
      this.engage();
      this.handleOptionChange(ev);
    });
    host.addEventListener('keydown', (ev) => {
      if (ev.key === 'Escape' && this.activeSheetCard) {
        ev.preventDefault();
        const card = this.activeSheetCard;
        this.closeSheet();
        card.querySelector<HTMLButtonElement>('[data-rw-add]')?.focus({ preventScroll: true });
      }
    });

    this.sheetHost = host;
    return host;
  }

  private openSheet(card: HTMLElement, picker: HTMLElement): void {
    if (this.activeSheetCard === card) return;
    if (this.activeSheetCard) this.closeSheet();

    const host = this.ensureSheetHost();
    const cs = getComputedStyle(this);
    for (const tok of SHEET_TOKENS) {
      const val = cs.getPropertyValue(tok);
      if (val) host.style.setProperty(tok, val);
    }
    host.style.fontFamily = cs.fontFamily;
    host.style.color = cs.color;

    const placeholder = document.createComment('rw-picker-slot');
    picker.parentNode?.insertBefore(placeholder, picker);

    this.activeSheetCard = card;
    this.activeSheetPicker = picker;
    this.activeSheetPlaceholder = placeholder;

    picker.hidden = false;
    host.appendChild(picker);
    document.body.appendChild(host);
    void host.offsetWidth;
    host.classList.add('is-open');
    this.classList.add('rw--picking');
    card.classList.add('is-picking');
    card.querySelector<HTMLButtonElement>('[data-rw-add]')?.setAttribute('aria-expanded', 'true');

    const checked = picker.querySelector<HTMLInputElement>('input[type="radio"]:checked');
    checked?.focus({ preventScroll: true });
  }

  private closeSheet(): void {
    if (!this.activeSheetCard || !this.activeSheetPicker) return;
    const card = this.activeSheetCard;
    const picker = this.activeSheetPicker;
    const placeholder = this.activeSheetPlaceholder;

    picker.hidden = true;
    if (placeholder && placeholder.parentNode) {
      placeholder.parentNode.insertBefore(picker, placeholder);
      placeholder.remove();
    } else {
      card.appendChild(picker);
    }

    this.sheetHost?.classList.remove('is-open');
    this.sheetHost?.remove();
    this.classList.remove('rw--picking');
    card.classList.remove('is-picking');
    if (!card.classList.contains('is-added')) {
      card.querySelector<HTMLButtonElement>('[data-rw-add]')?.setAttribute('aria-expanded', 'false');
    }

    this.activeSheetCard = null;
    this.activeSheetPicker = null;
    this.activeSheetPlaceholder = null;
  }

  private confirmCard(confirmBtn: HTMLButtonElement): void {
    const picker = confirmBtn.closest<HTMLElement>('[data-rw-picker]');
    const card =
      this.activeSheetPicker === picker
        ? this.activeSheetCard
        : confirmBtn.closest<HTMLElement>('[data-rw-card]');
    if (!card || !picker || card.classList.contains('is-added')) return;

    this.engage();
    card.dataset.touched = '1';
    const variantId = Number(card.dataset.selected);
    const panel = card.closest<HTMLElement>('[data-rw-panel]');
    const msgEl = panel?.querySelector<HTMLElement>('[data-rw-msg]') || null;
    if (msgEl) msgEl.textContent = '';

    card.classList.add('is-loading');
    try {
      stylingBag.add([{ id: variantId, quantity: 1 }]);
      card.classList.remove('is-loading');
      this.markCardAdded(card);
      if (this.isMobile && !this.reducedMotion && typeof navigator.vibrate === 'function') {
        try {
          navigator.vibrate(12);
        } catch {
          // ignore
        }
      }
      if (panel) this.checkPanelComplete(panel);
    } catch {
      card.classList.remove('is-loading');
      if (msgEl) {
        msgEl.textContent = this.dataset.msgError || 'Couldn’t add to bag. Please try again.';
      }
    }
  }

  private markCardAdded(card: HTMLElement): void {
    if (this.activeSheetCard === card) {
      this.closeSheet();
    } else {
      const picker = card.querySelector<HTMLElement>('[data-rw-picker]');
      if (picker) picker.hidden = true;
    }
    card.classList.remove('is-picking');
    card.classList.add('is-added');
    const addBtn = card.querySelector<HTMLButtonElement>('[data-rw-add]');
    if (addBtn) {
      const addedLabel = addBtn.dataset.addedLabel;
      if (addedLabel) addBtn.setAttribute('aria-label', addedLabel);
      addBtn.removeAttribute('aria-expanded');
    }
  }

  private addFullLook(panel: HTMLElement, cta: HTMLButtonElement): void {
    if (panel.classList.contains('is-complete') || cta.classList.contains('is-loading')) return;
    this.engage();

    const msgEl = panel.querySelector<HTMLElement>('[data-rw-msg]');
    if (msgEl) msgEl.textContent = '';

    const cards = Array.from(panel.querySelectorAll<HTMLElement>('[data-rw-card]')).filter(
      (c) => !c.classList.contains('is-added') && c.dataset.soldout !== '1'
    );

    const ready: Array<{ card: HTMLElement; id: number }> = [];
    const pending: HTMLElement[] = [];

    for (const c of cards) {
      const directId = Number(c.dataset.variantId || 0);
      const selectedId = Number(c.dataset.selected || 0);
      if (directId > 0) {
        ready.push({ card: c, id: directId });
      } else if (c.dataset.touched === '1' && selectedId > 0) {
        ready.push({ card: c, id: selectedId });
      } else {
        pending.push(c);
      }
    }

    if (ready.length > 0) {
      cta.classList.add('is-loading');
      for (const r of ready) r.card.classList.add('is-loading');
      try {
        stylingBag.add(ready.map((r) => ({ id: r.id, quantity: 1 })));
        for (const r of ready) {
          r.card.classList.remove('is-loading');
          this.markCardAdded(r.card);
        }
      } catch {
        for (const r of ready) r.card.classList.remove('is-loading');
        if (msgEl) {
          msgEl.textContent = this.dataset.msgError || 'Couldn’t add to bag. Please try again.';
        }
      }
      cta.classList.remove('is-loading');
    }

    if (pending.length > 0) {
      if (this.isMobile) {
        this.togglePicker(pending[0], true);
      } else {
        for (const p of pending) {
          this.togglePicker(p, true);
        }
        this.revealCard(pending[0]);
      }

      if (msgEl) {
        const tmpl = this.dataset.msgChoose || 'Pick a size for: [items]';
        const names = pending.map((c) => c.dataset.title || '').filter(Boolean).join(', ');
        msgEl.textContent = tmpl.replace('[items]', names);
      }
    }

    this.checkPanelComplete(panel);
  }

  private checkPanelComplete(panel: HTMLElement): void {
    const allCards = Array.from(panel.querySelectorAll<HTMLElement>('[data-rw-card]'));
    if (allCards.length >= 2 && allCards.every((c) => c.classList.contains('is-added'))) {
      panel.classList.add('is-complete');
      const msgEl = panel.querySelector<HTMLElement>('[data-rw-msg]');
      if (msgEl) msgEl.textContent = '';
    }
  }
}

export function registerRunwaySection(): void {
  if (!customElements.get('runway-section')) {
    customElements.define('runway-section', RunwaySection);
  }
}
