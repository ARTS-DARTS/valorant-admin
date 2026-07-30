export const CONTENT_CATEGORIES = Object.freeze({
  lineup: Object.freeze({
    title: 'ЛАЙНАПЫ',
    label: 'лайнап',
    plural: 'лайнапов',
    empty: 'Лайнапы не найдены',
  }),
  combo: Object.freeze({
    title: 'КОМБО',
    label: 'комбо',
    plural: 'комбо',
    empty: 'Комбо не найдены',
  }),
  wallbang: Object.freeze({
    title: 'ПРОСТРЕЛЫ',
    label: 'прострел',
    plural: 'прострелов',
    empty: 'Прострелы не найдены',
    legacy: Object.freeze(['smoke']),
  }),
  defense: Object.freeze({
    title: 'ЗАЩИТА',
    label: 'защита',
    plural: 'защит',
    empty: 'Защита не найдена',
  }),
});

const ENABLED_CONTENT_SAVE_CATEGORIES = new Set([
  'lineup',
  'wallbang',
  'defense',
]);

export function normalizeContentCategory(value) {
  if (!value) return 'lineup';
  if (value === 'smoke') return 'wallbang';
  return value;
}

export function canSaveContentCategory(value) {
  return ENABLED_CONTENT_SAVE_CATEGORIES.has(
    normalizeContentCategory(value),
  );
}

export function contentCategoryOf(item) {
  return normalizeContentCategory(item?.content_type || item?.category);
}

export function contentMeta(category) {
  return CONTENT_CATEGORIES[category] || CONTENT_CATEGORIES.lineup;
}
