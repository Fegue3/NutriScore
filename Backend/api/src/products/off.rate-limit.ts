import Bottleneck from 'bottleneck';

// Product detail limiter (90/min em vez de 100)
export const offProductLimiter = new Bottleneck({
  reservoir: 90,                // máximo tokens disponíveis
  reservoirRefreshAmount: 90,   // reabastece 90
  reservoirRefreshInterval: 60 * 1000, // a cada 60s
  maxConcurrent: 2,             // no máx 2 em paralelo
});

// Search limiter (5/min em vez de 10)
export const offSearchLimiter = new Bottleneck({
  reservoir: 5,
  reservoirRefreshAmount: 5,
  reservoirRefreshInterval: 60 * 1000,
  maxConcurrent: 1,
});

// Facet limiter (1/min em vez de 2)
export const offFacetLimiter = new Bottleneck({
  reservoir: 1,
  reservoirRefreshAmount: 1,
  reservoirRefreshInterval: 60 * 1000,
  maxConcurrent: 1,
});
