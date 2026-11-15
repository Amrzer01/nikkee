import test from 'node:test';
import assert from 'node:assert/strict';
import { CATALOG } from './catalog';
import {
  addItemsToBag,
  buildShortlistText,
  buildVariantIndex,
  countBagQuantity,
  findMatchingVariant,
  formatMoney,
  isOptionValueAvailable,
  parseBagEntries,
  validateCatalog,
  validateProductUrl,
} from './bag';

test('catalog passes validation and covers all 6 looks and 8 items', () => {
  const cat = validateCatalog(CATALOG);
  assert.equal(cat.looks.length, 6);
  assert.equal(cat.items.length, 8);
  assert.throws(() => validateCatalog(null), /The product list is unavailable\./);
});

test('variant matching and option availability work cleanly', () => {
  const aj12 = CATALOG.items[0];
  const v42 = findMatchingVariant(aj12.variants, ['42']);
  assert.equal(v42?.id, 57015167090993);
  assert.equal(isOptionValueAvailable(aj12.variants, 0, '42', ['40']), true);
});

test('bag persistence filters invalid rows, caps at 50 and qty 20', () => {
  const entries = parseBagEntries(
    JSON.stringify([
      { id: 57015167025457, quantity: 2 },
      { id: 123, quantity: 0 },
      { id: 456, quantity: 25 },
      { id: 'bad', quantity: 1 },
    ])
  );
  assert.deepEqual(entries, [{ id: 57015167025457, quantity: 2 }]);
});

test('addItemsToBag validates variants, increments quantity, and formats shortlist', () => {
  const idx = buildVariantIndex(CATALOG);
  let bag = addItemsToBag([], [{ id: 57015167025457, quantity: 1 }], idx);
  bag = addItemsToBag(bag, [{ id: 57015167025457, quantity: 1 }], idx);
  assert.equal(countBagQuantity(bag), 2);
  assert.equal(formatMoney(149), '$149.00');

  assert.throws(
    () => addItemsToBag(bag, [{ id: 999999, quantity: 1 }], idx),
    /Please choose an available size\./
  );

  const text = buildShortlistText(bag, idx);
  assert.ok(text.includes('RUNWAY — STYLING SHORTLIST'));
  assert.ok(text.includes('Air Jordan 12 Retro · Size 40 · Quantity 2'));
  assert.ok(text.includes('https://nike-makknzjs.myshopify.com/products/tatum-5-orbit-copy'));
});

test('validateProductUrl enforces allowed Shopify host', () => {
  assert.equal(
    validateProductUrl('https://nike-makknzjs.myshopify.com/products/tshirt'),
    'https://nike-makknzjs.myshopify.com/products/tshirt'
  );
  assert.throws(() => validateProductUrl('https://evil.example.com/products/tshirt'));
});
