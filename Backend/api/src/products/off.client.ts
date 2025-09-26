import axios from 'axios';
import {
  offProductLimiter,
  offSearchLimiter,
  offFacetLimiter,
} from './off.rate-limit';

const OFF_BASE = process.env.OFF_BASE ?? 'https://world.openfoodfacts.org';

export type OffProduct = {
  code: string;
  product_name?: string;
  brands?: string;
  quantity?: string;
  serving_size?: string;
  image_front_url?: string;
  countries?: string;
  nutriscore_grade?: string;   // a..e
  nutriscore_score?: number;
  nova_group?: number;         // 1..4
  ecoscore_grade?: string;     // a..e
  categories?: string;
  labels?: string;
  allergens?: string;
  ingredients_text?: string;
  nutriments?: {
    ['energy-kcal_100g']?: number;
    proteins_100g?: number;
    carbohydrates_100g?: number;
    sugars_100g?: number;
    fat_100g?: number;
    'saturated-fat_100g'?: number;
    fiber_100g?: number;
    salt_100g?: number;
    sodium_100g?: number;

    // por porção
    ['energy-kcal_serving']?: number;
    proteins_serving?: number;
    carbohydrates_serving?: number;
    sugars_serving?: number;
    fat_serving?: number;
    'saturated-fat_serving'?: number;
    fiber_serving?: number;
    salt_serving?: number;
    sodium_serving?: number;
  };
};

// ----------------- Produto (90/min) -----------------
export async function offFetchByBarcode(barcode: string) {
  return offProductLimiter.schedule(async () => {
    const url = `${OFF_BASE}/api/v2/product/${encodeURIComponent(barcode)}.json`;
    const { data } = await axios.get(url, { timeout: 8000 });
    if (!data || !data.product) return null;
    return data.product as OffProduct;
  });
}

// ----------------- Pesquisa (5/min) -----------------
export async function offSearch(q: string, page = 1, pageSize = 20) {
  return offSearchLimiter.schedule(async () => {
    const url = `${OFF_BASE}/cgi/search.pl`;
    const params = {
      search_terms: q,
      search_simple: 1,
      json: 1,
      page,
      page_size: pageSize,
      fields: [
        'code',
        'product_name',
        'brands',
        'nutriscore_grade',
        'nutriscore_score',
        'nova_group',
        'ecoscore_grade',
        'categories',
        'image_front_url',
        'nutriments',
      ].join(','),
    };
    const { data } = await axios.get(url, { params, timeout: 9000 });
    return {
      count: data?.count ?? 0,
      products: (data?.products ?? []) as OffProduct[],
    };
  });
}

// ----------------- Facets (1/min) -----------------
export async function offFacet(path: string) {
  return offFacetLimiter.schedule(async () => {
    const url = `${OFF_BASE}${path}.json`;
    const { data } = await axios.get(url, { timeout: 8000 });
    return data;
  });
}
