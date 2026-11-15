import { CATALOG, CatalogItem, CatalogVariant, RunwayCatalog } from './catalog';

export const BAG_STORAGE_KEY = 'runway-styling-bag-v3';
export const ALLOWED_PRODUCT_HOST = 'nike-makknzjs.myshopify.com';

export interface BagEntry {
  id: number;
  quantity: number;
}

export interface VariantMatch {
  item: CatalogItem;
  variant: CatalogVariant;
}

export function validateCatalog(raw: unknown): RunwayCatalog {
  if (!raw || typeof raw !== 'object') {
    throw new Error('The product list is unavailable.');
  }
  const obj = raw as Record<string, unknown>;
  if (!Array.isArray(obj.items)) {
    throw new Error('The product list is unavailable.');
  }
  for (const item of obj.items) {
    if (!item || typeof item !== 'object') {
      throw new Error('The product list is unavailable.');
    }
    const it = item as Record<string, unknown>;
    if (
      typeof it.id !== 'string' ||
      !it.id ||
      typeof it.name !== 'string' ||
      !it.name ||
      typeof it.price !== 'number' ||
      !Number.isFinite(it.price) ||
      it.price < 0 ||
      !Array.isArray(it.variants)
    ) {
      throw new Error('The product list is unavailable.');
    }
    for (const v of it.variants) {
      if (!v || typeof v !== 'object') {
        throw new Error('The product list is unavailable.');
      }
      const vr = v as Record<string, unknown>;
      if (
        typeof vr.id !== 'number' ||
        !Number.isSafeInteger(vr.id) ||
        typeof vr.a !== 'boolean' ||
        !Array.isArray(vr.o) ||
        !vr.o.every((opt) => typeof opt === 'string')
      ) {
        throw new Error('The product list is unavailable.');
      }
    }
  }
  return obj as unknown as RunwayCatalog;
}

export function buildVariantIndex(catalog: RunwayCatalog): Map<number, VariantMatch> {
  const map = new Map<number, VariantMatch>();
  for (const item of catalog.items) {
    for (const variant of item.variants) {
      map.set(variant.id, { item, variant });
    }
  }
  return map;
}

export function findMatchingVariant(
  variants: CatalogVariant[],
  selectedOptions: string[]
): CatalogVariant | undefined {
  return variants.find(
    (v) =>
      v.o.length === selectedOptions.length &&
      v.o.every((opt, idx) => opt === selectedOptions[idx])
  );
}

export function isOptionValueAvailable(
  variants: CatalogVariant[],
  optionIndex: number,
  value: string,
  selectedOptions: string[]
): boolean {
  return variants.some(
    (v) =>
      v.a &&
      v.o[optionIndex] === value &&
      selectedOptions.every((sel, idx) => idx === optionIndex || v.o[idx] === sel)
  );
}

export function parseBagEntries(rawJson: string | null): BagEntry[] {
  if (!rawJson) return [];
  try {
    const parsed = JSON.parse(rawJson);
    if (!Array.isArray(parsed)) return [];
    const out: BagEntry[] = [];
    for (const entry of parsed) {
      if (!entry || typeof entry !== 'object') continue;
      const id = (entry as Record<string, unknown>).id;
      const quantity = (entry as Record<string, unknown>).quantity;
      if (
        typeof id === 'number' &&
        Number.isSafeInteger(id) &&
        typeof quantity === 'number' &&
        Number.isSafeInteger(quantity) &&
        quantity >= 1 &&
        quantity <= 20
      ) {
        out.push({ id, quantity });
        if (out.length >= 50) break;
      }
    }
    return out;
  } catch {
    return [];
  }
}

export function addItemsToBag(
  current: BagEntry[],
  toAdd: Array<{ id: number; quantity: number }>,
  variantIndex: Map<number, VariantMatch>
): BagEntry[] {
  const next = current.map((e) => ({ ...e }));
  for (const req of toAdd) {
    const match = variantIndex.get(req.id);
    if (!match || !match.variant.a) {
      throw new Error('Please choose an available size.');
    }
    const existing = next.find((e) => e.id === req.id);
    if (existing) {
      existing.quantity = Math.min(20, existing.quantity + Math.max(1, req.quantity));
    } else if (next.length < 50) {
      next.push({ id: req.id, quantity: Math.min(20, Math.max(1, req.quantity)) });
    }
  }
  return next;
}

export function countBagQuantity(entries: BagEntry[]): number {
  return entries.reduce((sum, entry) => sum + entry.quantity, 0);
}

const usdFormatter = new Intl.NumberFormat('en-US', {
  style: 'currency',
  currency: 'USD',
});

export function formatMoney(amount: number): string {
  return usdFormatter.format(amount);
}

export function validateProductUrl(urlString: string): string {
  const url = new URL(urlString);
  if (url.hostname !== ALLOWED_PRODUCT_HOST) {
    throw new Error(`Invalid product URL host: ${url.hostname}`);
  }
  return url.toString();
}

export function buildShortlistText(
  entries: BagEntry[],
  variantIndex: Map<number, VariantMatch>
): string {
  const parts: string[] = [
    'RUNWAY — STYLING SHORTLIST',
    'Reference prices; no order or payment has been placed.',
    '',
  ];
  for (const entry of entries) {
    const match = variantIndex.get(entry.id);
    if (!match) continue;
    const size = match.variant.o.join(' / ');
    parts.push(`${match.item.name} · Size ${size} · Quantity ${entry.quantity}`);
    parts.push(validateProductUrl(match.item.url));
  }
  return parts.join('\n\n');
}

export class StylingBag {
  private catalog: RunwayCatalog | null = null;
  private variantIndex = new Map<number, VariantMatch>();
  private entries: BagEntry[] = [];
  private toastTimer: number | null = null;

  private dialogEl: HTMLDialogElement | null = null;
  private itemsEl: HTMLElement | null = null;
  private totalEl: HTMLElement | null = null;
  private exportBtn: HTMLButtonElement | null = null;
  private statusEl: HTMLElement | null = null;

  constructor() {
    this.entries = this.loadFromStorage();
  }

  ensureCatalog(): RunwayCatalog {
    if (!this.catalog) {
      try {
        this.catalog = validateCatalog(CATALOG);
        this.variantIndex = buildVariantIndex(this.catalog);
      } catch (err) {
        if (err instanceof Error && err.message === 'The product list is unavailable.') {
          throw err;
        }
        throw new Error('The product list could not load.');
      }
    }
    return this.catalog;
  }

  private loadFromStorage(): BagEntry[] {
    try {
      return parseBagEntries(window.localStorage.getItem(BAG_STORAGE_KEY));
    } catch {
      return [];
    }
  }

  private saveToStorage(): void {
    try {
      window.localStorage.setItem(BAG_STORAGE_KEY, JSON.stringify(this.entries));
    } catch {
      // ignore storage failure
    }
  }

  mount(doc: Document = document): void {
    this.dialogEl = doc.getElementById('bag-dialog') as HTMLDialogElement | null;
    this.itemsEl = doc.getElementById('bag-items');
    this.totalEl = doc.getElementById('bag-total');
    this.exportBtn = doc.getElementById('export-bag') as HTMLButtonElement | null;
    this.statusEl = doc.getElementById('bag-status');

    const openBtn = doc.getElementById('open-bag');
    const closeBtn = doc.getElementById('close-bag');

    openBtn?.addEventListener('click', () => {
      this.render();
      this.dialogEl?.showModal();
    });

    closeBtn?.addEventListener('click', () => {
      this.dialogEl?.close();
    });

    this.dialogEl?.addEventListener('click', (ev) => {
      if (!this.dialogEl) return;
      const rect = this.dialogEl.getBoundingClientRect();
      const inside =
        ev.clientX >= rect.left &&
        ev.clientX <= rect.right &&
        ev.clientY >= rect.top &&
        ev.clientY <= rect.bottom;
      if (!inside) {
        this.dialogEl.close();
      }
    });

    this.exportBtn?.addEventListener('click', () => {
      this.exportShortlist();
    });

    this.updateCounts();
  }

  add(items: Array<{ id: number; quantity: number }>): void {
    this.ensureCatalog();
    this.entries = addItemsToBag(this.entries, items, this.variantIndex);
    this.saveToStorage();
    this.updateCounts();
    if (this.dialogEl?.open) {
      this.render();
    }
    this.showToast(
      items.length > 1
        ? 'Look saved to your styling bag'
        : 'Piece saved to your styling bag'
    );
  }

  remove(variantId: number): void {
    this.entries = this.entries.filter((e) => e.id !== variantId);
    this.saveToStorage();
    this.render();
  }

  updateCounts(): void {
    const totalQty = countBagQuantity(this.entries);
    document.querySelectorAll('[data-cart-count]').forEach((el) => {
      el.textContent = String(totalQty);
    });
  }

  showToast(message: string): void {
    if (!this.statusEl) return;
    if (this.toastTimer !== null) {
      window.clearTimeout(this.toastTimer);
      this.toastTimer = null;
    }
    this.statusEl.classList.remove('is-on');
    this.statusEl.textContent = message;
    void this.statusEl.offsetWidth;
    this.statusEl.classList.add('is-on');
    this.toastTimer = window.setTimeout(() => {
      this.statusEl?.classList.remove('is-on');
      this.toastTimer = null;
    }, 2500);
  }

  render(): void {
    this.ensureCatalog();
    this.updateCounts();
    if (!this.itemsEl || !this.totalEl || !this.exportBtn) return;

    this.itemsEl.replaceChildren();

    if (this.entries.length === 0) {
      const empty = document.createElement('p');
      empty.className = 'bag-note';
      empty.textContent =
        'Your styling bag is empty. Choose a size beside a piece to save it.';
      this.itemsEl.appendChild(empty);
      this.totalEl.textContent = '';
      this.exportBtn.disabled = true;
      return;
    }

    let subtotal = 0;

    for (const entry of this.entries) {
      const match = this.variantIndex.get(entry.id);
      if (!match) continue;
      const { item, variant } = match;
      subtotal += item.price * entry.quantity;

      const row = document.createElement('div');
      row.className = 'bag-row';

      const img = document.createElement('img');
      img.src = item.image;
      img.alt = item.name;
      img.width = 60;
      img.height = 80;

      const details = document.createElement('div');
      const title = document.createElement('h3');
      title.textContent = item.name;

      const meta = document.createElement('p');
      const sizeText = variant.o.join(' / ');
      meta.textContent = `Size ${sizeText} · Quantity ${entry.quantity} · ${formatMoney(item.price)}`;

      const link = document.createElement('a');
      link.href = validateProductUrl(item.url);
      link.target = '_blank';
      link.rel = 'noopener noreferrer';
      link.textContent = 'View original piece ↗';

      details.append(title, meta, link);

      const removeBtn = document.createElement('button');
      removeBtn.type = 'button';
      removeBtn.className = 'bag-remove';
      removeBtn.setAttribute('aria-label', `Remove ${item.name}`);
      removeBtn.textContent = '×';
      removeBtn.addEventListener('click', () => this.remove(entry.id));

      row.append(img, details, removeBtn);
      this.itemsEl.appendChild(row);
    }

    this.totalEl.textContent = `Reference subtotal ${formatMoney(subtotal)}`;
    this.exportBtn.disabled = false;
  }

  exportShortlist(): void {
    if (this.entries.length === 0) return;
    this.ensureCatalog();
    const content = buildShortlistText(this.entries, this.variantIndex);
    const blob = new Blob([content], { type: 'text/plain;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'runway-outfit-shortlist.txt';
    document.body.appendChild(a);
    a.click();
    a.remove();
    window.setTimeout(() => URL.revokeObjectURL(url), 1000);
  }
}

export const stylingBag = new StylingBag();
